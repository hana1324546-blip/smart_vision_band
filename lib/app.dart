import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_state_providers.dart';
import 'core/permissions.dart';
import 'features/settings/language_toggle.dart';
import 'features/hub/home_dashboard.dart';
import 'features/live/assistant_dashboard.dart';
import 'features/caregiver/progress_dashboard.dart';
import 'l10n/app_localizations.dart';

class SmartVisionApp extends ConsumerWidget {
 const SmartVisionApp({super.key});

 @override
 Widget build(BuildContext context,WidgetRef ref) {
  final app=ref.watch(appProvider);
  return MaterialApp(
   title:'Insight Wear',
   debugShowCheckedModeBanner:false,
   locale:app.locale,
   supportedLocales:AppLocalizations.supportedLocales,
   localizationsDelegates:const [
	AppLocalizations.delegate,
	GlobalMaterialLocalizations.delegate,
	GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
   ],
   theme:ThemeData(useMaterial3:true,brightness:Brightness.light,colorScheme:const ColorScheme.light(primary:Color(0xff35458f),onPrimary:Colors.white,surface:Colors.white,onSurface:Color(0xff20243a),outlineVariant:Color(0xffd9d9e3)),scaffoldBackgroundColor:const Color(0xfff4f3f8),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(minimumSize:const Size(64,52)))),
   home:const Screens(),
  );
 }
}

class Screens extends ConsumerStatefulWidget {
 const Screens({super.key});
 @override ConsumerState<Screens> createState()=>_ScreensState();
}

class _ScreensState extends ConsumerState<Screens> {
 int tab=0;
 @override
 void initState(){super.initState();Future.microtask(()=>ref.read(appProvider).guard(ref.read(appProvider).init));}

 @override
 Widget build(BuildContext context){
 final a=ref.watch(appProvider);
 final strings=AppLocalizations.of(context);
 final titles=[
  strings.text('permissions'),strings.text('deviceHub'),strings.text('liveNavigation'),
  strings.text('settings'),strings.text('caregiverDashboard'),strings.text('debugConsole'),
 ];
 String levelName(Object? value) {
   final raw=(value?.toString()??'unknown').split('.').last;
   if(raw.isEmpty)return strings.text('levelUnknown');
   final key='level${raw[0].toUpperCase()}${raw.substring(1)}';
  return strings.text(key);
 }
 Widget button(String text,Future<void> Function() fn,{bool enabled=true})=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:FilledButton(onPressed:enabled?()=>a.guard(fn):null,child:Text(text)));
 final children=<Widget>[];
 switch(tab){
 case 0:
 children.add(HomeDashboard(app:a,onOpenDevices:()=>setState(()=>tab=1),onStartNavigation:()async{await a.start();setState(()=>tab=2);}));
 case 1:
 children.addAll([Text('${strings.text('esp32Stream')} — ${strings.text(a.cameraReady?'connected':'disconnected')}'),Text('${strings.text('streamFps')}: ${a.fps.toStringAsFixed(1)}'),Text('${strings.text('bluetoothBand')} — ${strings.text(a.connected?'connected':a.reconnecting?'reconnecting':'disconnected')}'),Text('${strings.text('bluetoothEarbuds')} — ${strings.text(a.earbuds?'active':'notRouted')}'),Text('${strings.text('hardwareStatus')}: ${strings.text(a.receivingUltrasonic?'receiving':'notReceiving')}'),Text('${strings.text('battery')}: ${a.batteryPercent?.toStringAsFixed(0)??strings.text('notReported')}%'),
 button(strings.text('connectStream'),a.camera.start),
 button(strings.text('selectBonded'),()async{
 final devices=await a.bluetooth.bonded();if(!context.mounted)return;
 final mac=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:Text(strings.text('choosePaired')),children:devices.map((d)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,d['address'] as String),child:Padding(padding:const EdgeInsets.all(12),child:Text('${d['name']} ${d['address']}')))).toList()));
 if(mac!=null){await a.bluetooth.connect(mac);await(await SharedPreferences.getInstance()).setString('mac',mac);}
 }),button(strings.text('reconnectSaved'),()async{final mac=(await SharedPreferences.getInstance()).getString('mac');if(mac==null)throw StateError(strings.text('selectBandFirst'));await a.bluetooth.connect(mac);}),
 button(strings.text('refreshEarbuds'),()async{a.earbuds=await a.audio.earbudsActive;a.update();}),
 button(strings.text('grantPermissions'),requestRequiredPermissions),
 button(strings.text('startNavigation'),()async{await a.start();setState(()=>tab=2);},enabled:a.demo||a.connected,),Text(a.cameraReady?strings.text('modelReady'):strings.text('sensorOnlyMode'))]);
 case 2:
 children.add(AssistantDashboard(isListening:a.listeningForCommand,distanceLabel:a.distance==null?strings.text('distanceUnavailable'):'${a.distance!.cm.toStringAsFixed(0)} ${strings.text('centimeters')}',detections:a.detections,onListen:a.activateVoiceAssistant));
 case 3:
 final intensityLabels={'Soft':strings.text('soft'),'Medium':strings.text('medium'),'Strong':strings.text('strong')};
 children.addAll([LanguageToggle(isArabic:a.languageCode=='ar',onChanged:(value)=>a.guard(()=>a.setLanguage(value?'ar':'en'))),
 DropdownButtonFormField<String>(value:a.intensity,decoration:InputDecoration(labelText:strings.text('intensityPreference')),items:intensityLabels.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v){a.intensity=v!;a.update();}),
 Text('${strings.text('confidence')} ${a.confidence.toStringAsFixed(2)}'),Slider(value:a.confidence,min:.3,max:.7,divisions:8,label:a.confidence.toStringAsFixed(2),onChanged:(v){a.confidence=v;a.update();},onChangeEnd:(v){a.guard(()=>a.camera.configure(v));}),
 SwitchListTile(title:Text(strings.text('firebase')),value:false,onChanged:null),
 SwitchListTile(title:Text(strings.text('batterySaver')),value:a.batterySaver,onChanged:(v){a.batterySaver=v;a.update();})]);
 case 4:
 children.addAll([ProgressDashboard(bluetoothConnected:a.connected,streamReady:a.cameraReady,receivingUltrasonic:a.receivingUltrasonic,fps:a.fps,batteryPercent:a.batteryPercent),
 button(strings.text('exportEvents'),()async{final f=File('${(await getTemporaryDirectory()).path}/smart_vision_events.csv');await f.writeAsString(await a.repo.csv());await Share.shareXFiles([XFile(f.path)],text:strings.text('shareEvents'));})]);
 case 5:
 children.addAll([SwitchListTile(title:Text(strings.text('demoMode')),value:a.demo,onChanged:a.running?null:(v){a.demo=v;a.distance=null;a.update();}),Text('${strings.text('fps')} ${a.fps} | ${strings.text('latency')} ${a.latency} ms'),...a.detections.take(10).map((d)=>Text('${d.label}: ${d.confidence}')),...a.logs.reversed.take(100).map((s)=>SelectableText(s))]);
 }
 final content=SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
 if(a.running&&!a.demo&&!a.connected)Container(color:Colors.red.shade900,padding:const EdgeInsets.all(16),child:Text(strings.text('emergencyBandLost'),style:const TextStyle(fontSize:24))),
 if(a.error.isNotEmpty)Text(a.error,style:const TextStyle(color:Colors.amber)),...children.map((w)=>Padding(padding:const EdgeInsets.only(bottom:16),child:w))]));
 final mainTab=tab==0?0:tab==2?1:tab==4?2:null;
 return Scaffold(appBar:AppBar(title:Text(titles[tab]),actions:[if(tab!=3)IconButton(tooltip:strings.text('settings'),icon:const Icon(Icons.settings_outlined),onPressed:()=>setState(()=>tab=3))]),drawer:Drawer(child:SafeArea(child:ListView(children:[for(var i=0;i<titles.length;i++)ListTile(title:Text(titles[i]),selected:i==tab,onTap:(){Navigator.pop(context);setState(()=>tab=i);})]))),body:tab==2?GestureDetector(behavior:HitTestBehavior.translucent,onDoubleTap:a.listeningForCommand?null:a.activateVoiceAssistant,child:content):content,bottomNavigationBar:NavigationBar(selectedIndex:mainTab??0,onDestinationSelected:(index)=>setState(()=>tab=[0,2,4][index]),destinations:[NavigationDestination(icon:const Icon(Icons.home_outlined),selectedIcon:const Icon(Icons.home),label:strings.text('home')),NavigationDestination(icon:const Icon(Icons.assistant_outlined),selectedIcon:const Icon(Icons.assistant),label:strings.text('liveNavigation')),NavigationDestination(icon:const Icon(Icons.favorite_border),selectedIcon:const Icon(Icons.favorite),label:strings.text('progressTitle'))]));
 }
}
