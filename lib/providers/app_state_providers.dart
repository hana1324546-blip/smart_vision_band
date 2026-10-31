import 'dart:async';
import 'dart:ui' show Locale;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/detection.dart';
import '../models/distance_event.dart';
import '../models/danger_level.dart';
import '../services/bluetooth_service.dart';
import '../services/camera_channel_service.dart';
import '../services/audio_route_service.dart';
import '../services/foreground_service.dart';
import '../services/tts_service.dart';
import '../services/sensor_fusion_service.dart';
import '../services/event_repository.dart';
import '../services/voice_command_service.dart';
final appProvider = ChangeNotifierProvider((ref)=>AppController());
class AppController extends ChangeNotifier {
 final bluetooth=BluetoothService(), camera=CameraChannelService();
 final audio=AudioRouteService(), service=ForegroundService();
 final tts=TtsService(), repo=EventRepository(), fusion=SensorFusionService();
 final voiceCommands=VoiceCommandService();
 bool connected=false, reconnecting=false, cameraReady=false, running=false, demo=false, earbuds=false;
 bool receivingUltrasonic=false;
 bool listeningForCommand=false;
 double? batteryPercent;
 bool batterySaver=true;
 bool _languageManuallyChanged=false;
 double confidence=.5, latency=0, fps=0;
 String languageCode='en';
 Locale get locale=>Locale(languageCode);
 String error='', intensity='Medium';
 final logs=<String>[];
 List<Detection> detections=[];
 DistanceEvent? distance;
 DateTime? detectedAt;
 Decision decision=const Decision(DangerLevel.unknown,'VIBRATE_OFF','');
 Timer? timer, telemetryTimer;
 StreamSubscription<dynamic>? btSub, camSub;
 Completer<List<Detection>>? _snapshotCompleter;
 int _snapshotRequestId=0;
 int? _pendingSnapshotId;
 bool busy=false;
 String lastCommand='',lastVoice='';
 DateTime lastHaptic=DateTime.fromMillisecondsSinceEpoch(0);
 void log(String text){logs.add('${DateTime.now().toIso8601String()} $text');if(logs.length>300)logs.removeAt(0);}
 Future<void> guard(Future<void> Function() f) async {try{await f();}catch(e){error='$e';log(error);notifyListeners();}}
 Future<void> init() async {
  service.onExternalStop=()=>unawaited(stop(fromService:true));
  btSub=bluetooth.listenTelemetry((e,status){
    final lost=connected && !status.connected;
    connected=status.connected;
    reconnecting=status.reconnecting;
    batteryPercent=status.batteryPercent;
    receivingUltrasonic=status.receivingUltrasonic;
    if(lost && running){distance=null;unawaited(guard(()async{await audio.phoneVibrate();await tts.speak(languageCode=='ar'?'طوارئ: انقطع اتصال السوار':'Emergency: Band connection lost',urgent:true);}));}
   if(e['line']!=null){log('${e['type']}: ${e['line']}');
    if(e['type']=='rx'){final p=Protocol.parse(e['line'] as String);if(p?.key=='DIST'){distance=DistanceEvent(p!.value,status.lastDistanceAt??DateTime.now());if(running)unawaited(guard(tick));}}
   }
    notifyListeners();
  },onError:(Object e){error='$e';notifyListeners();});
  camSub=camera.events.listen((dynamic event){final e=event as Map;
   if(e['type']=='state')cameraReady=e['ready']==true;
    if(e['type']=='error'){error='${e['message']??'Camera stream failed'}';log(error);}
  if(e['detections']!=null&&e['languageCode']==languageCode){detections=(e['detections'] as List).map((x)=>Detection.fromJson(x as Map)).toList();detectedAt=DateTime.now();latency=(e['latencyMs'] as num).toDouble();fps=(e['fps'] as num?)?.toDouble()??0;final pending=_snapshotCompleter;if(pending!=null&&!pending.isCompleted&&e['snapshotId']==_pendingSnapshotId)pending.complete(List<Detection>.of(detections));}
   notifyListeners();
  },onError:(Object e){cameraReady=false;error='$e';notifyListeners();});
    final preferences=await SharedPreferences.getInstance();
    if(!_languageManuallyChanged)languageCode=preferences.getString('languageCode')=='ar'?'ar':'en';
    notifyListeners();
    await guard(()async{await tts.init(languageCode:languageCode);});
    await guard(()=>camera.setLanguage(languageCode));
    await guard(()async{earbuds=await audio.earbudsActive;});
    if(preferences.getBool('navigationActive')==true){
      running=true;
      final savedAddress=preferences.getString('mac');
      if(savedAddress!=null)unawaited(guard(()=>bluetooth.connect(savedAddress)));
      unawaited(guard(camera.start));
      timer=Timer.periodic(const Duration(milliseconds:100),(_)=>unawaited(guard(tick)));
      notifyListeners();
    }
    telemetryTimer ??= Timer.periodic(const Duration(milliseconds:500),(_){
     final receiving=bluetooth.telemetry.receivingUltrasonic;
     if(receiving!=receivingUltrasonic){receivingUltrasonic=receiving;notifyListeners();}
    });
 }
 Future<void> setLanguage(String code) async {
    if(code!='ar'&&code!='en')throw ArgumentError.value(code,'code');
  _languageManuallyChanged=true;
  final changed=languageCode!=code;
  if(changed){
   languageCode=code;
   detections=[];
   detectedAt=null;
   lastVoice='';
   notifyListeners();
  }
    final preferences=await SharedPreferences.getInstance();
    await preferences.setString('languageCode',code);
  if(!changed)return;
    await guard(()=>tts.setLanguage(code));
    await guard(()=>camera.setLanguage(code));
   detections=[];
   detectedAt=null;
   notifyListeners();
 }
 Future<void> activateVoiceAssistant() async {
  if(listeningForCommand)return;
  listeningForCommand=true;notifyListeners();
  try{
   final phrase=await voiceCommands.listenForArabicCommand();
   if(phrase==null||phrase.trim().isEmpty){
    await tts.speak(languageCode=='ar'?'لم أتعرف على الأمر':'I did not recognize a command');
    return;
   }
   final normalized=phrase.toLowerCase().replaceAll(' ','').replaceAll('؟','').replaceAll('،','').replaceAll('?','').replaceAll('.','').replaceAll('!','');
   if(normalized.contains('ماذاامامي')||normalized.contains('ماذاامامى')||normalized.contains('ماامامي')){
    await describeVisibleObjects();
   }else if(normalized.contains('حالةالبطارية')||normalized.contains('حالةالبطاريه')){
    await speakBatteryStatus();
   }else{
    await tts.speak(languageCode=='ar'?'لم أتعرف على الأمر':'I did not recognize that command');
   }
  }catch(e){error='$e';log(error);}
  finally{listeningForCommand=false;notifyListeners();}
 }
 Future<void> describeVisibleObjects() async {
  if(!demo&&!cameraReady){
   await tts.speak(languageCode=='ar'?'الكاميرا غير متصلة':'Camera stream is unavailable');
   return;
  }
  late final List<Detection> snapshot;
  if(demo){
   snapshot=List<Detection>.of(detections);
  }else{
   final pending=Completer<List<Detection>>();
  final requestId=++_snapshotRequestId;
   _snapshotCompleter=pending;
  _pendingSnapshotId=requestId;
   try{
   await camera.requestSnapshot(requestId);
    snapshot=await pending.future.timeout(const Duration(seconds:3),onTimeout:()=>const <Detection>[]);
  }finally{if(identical(_snapshotCompleter,pending)){_snapshotCompleter=null;_pendingSnapshotId=null;}}
  }
  final labels=snapshot.where((d)=>d.confidence>=confidence).map((d)=>d.label).toSet().toList();
  if(labels.isEmpty){
   await tts.speak(languageCode=='ar'?'لا توجد أشياء مرئية أمامك':'No objects detected ahead',urgent:true);
   return;
  }
  await tts.speak(languageCode=='ar'?'أمامك: ${labels.join('، ')}':'Ahead: ${labels.join(', ')}',urgent:true);
 }
 Future<void> speakBatteryStatus() async {
  final connection=connected
    ? (languageCode=='ar'?'متصل':'connected')
    : reconnecting
      ? (languageCode=='ar'?'جارٍ إعادة الاتصال':'reconnecting')
      : (languageCode=='ar'?'غير متصل':'disconnected');
  final battery=batteryPercent==null
    ? (languageCode=='ar'?'مستوى البطارية غير متاح':'battery level unavailable')
    : (languageCode=='ar'?'مستوى البطارية ${batteryPercent!.round()} بالمئة':'battery level ${batteryPercent!.round()} percent');
  final sensor=receivingUltrasonic
    ? (languageCode=='ar'?'مستشعر المسافة يستقبل البيانات':'ultrasonic data is being received')
    : (languageCode=='ar'?'لا توجد بيانات حديثة من مستشعر المسافة':'no recent ultrasonic data');
  await tts.speak(languageCode=='ar'?'حالة البلوتوث $connection. $battery. $sensor.':'Bluetooth is $connection. $battery. $sensor.',urgent:true);
 }
 Future<void> start() async {
  if(running)return;
  if(!demo && !connected)throw StateError('Connect the HC-05 band before starting navigation');
  if(!demo){
    final preferences=await SharedPreferences.getInstance();
    await preferences.setBool('navigationActive',true);
    try{await service.start();}catch(error){await preferences.setBool('navigationActive',false);rethrow;}
  }
  running=true;lastCommand='';lastVoice='';
  timer=Timer.periodic(const Duration(milliseconds:100),(_)=>unawaited(guard(tick)));notifyListeners();
 }
 Future<void> tick() async {
  if(!running||busy)return;busy=true;
  try{
   final now=DateTime.now();
    if(demo){distance=DistanceEvent([450.0,300.0,150.0,35.0][(now.second~/4)%4],now);detections=[Detection(languageCode=='ar'?'كرسي':'Chair',.9,.5,const [.2,.2,.8,.8])];detectedAt=now;}
    final next=fusion.decide(now:now,distance:distance,detections:detections,detectedAt:detectedAt,confidence:confidence,languageCode:languageCode);
    final decisionChanged=next.level!=decision.level||next.voice!=decision.voice;decision=next;
    final hapticElapsed=now.difference(lastHaptic).inMilliseconds;
    final repeat=(next.command=='S'||next.command=='W')&&hapticElapsed>=2500;
    final commandChanged=next.command!=lastCommand;
    if((commandChanged&&(next.command!='W'||hapticElapsed>=2500))||repeat){
    if(!demo){if(connected){await bluetooth.haptic(next.command);}else if(next.level!=DangerLevel.safe){await audio.phoneVibrate();}}
    lastCommand=next.command;lastHaptic=now;
   }
    if(next.voice!=lastVoice||decisionChanged){await tts.speak(next.voice,urgent:next.level==DangerLevel.danger);lastVoice=next.voice;}
    if(decisionChanged)await repo.add({'timestamp':now.millisecondsSinceEpoch,'obstacleClass':detections.isEmpty?null:detections.first.label,'confidence':detections.isEmpty?null:detections.first.confidence,'distanceCm':distance?.cm,'dangerLevel':next.level.name,'hapticPattern':next.command,'voiceAlertPlayed':next.voice.isEmpty?0:1,'aiLatencyMs':latency});
   notifyListeners();
  }finally{busy=false;}
 }
 Future<void> stop({bool fromService=false}) async {
  running=false;timer?.cancel();
  final preferences=await SharedPreferences.getInstance();
  await preferences.setBool('navigationActive',false);
  await guard(camera.stop);
  await guard(()async{if(!demo&&connected)await bluetooth.haptic('C');});
  await guard(tts.stop);
  if(!fromService)await guard(service.stop);
  notifyListeners();
 }
 void update(){notifyListeners();}
 @override void dispose(){timer?.cancel();telemetryTimer?.cancel();btSub?.cancel();camSub?.cancel();unawaited(voiceCommands.stop());super.dispose();}
}
