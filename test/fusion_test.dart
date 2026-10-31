import 'package:flutter_test/flutter_test.dart';
import 'package:smart_vision_band/models/distance_event.dart';
import 'package:smart_vision_band/models/detection.dart';
import 'package:smart_vision_band/models/danger_level.dart';
import 'package:smart_vision_band/services/sensor_fusion_service.dart';
void main(){
 final now=DateTime.utc(2026,1,1), fusion=SensorFusionService();
 Decision at(double cm)=>fusion.decide(now:now,distance:DistanceEvent(cm,now));
 test('distance thresholds map to strong, pulsed, and clear bytes',(){
  expect(at(29).command,'S');expect(at(29).level,DangerLevel.danger);
  expect(at(30).command,'W');expect(at(30).level,DangerLevel.warning);
  expect(at(60).command,'W');expect(at(60).level,DangerLevel.warning);
  expect(at(61).command,'C');expect(at(61).level,DangerLevel.safe);
 });
 test('missing and stale sensor are unknown',(){
  expect(fusion.decide(now:now).level,DangerLevel.unknown);
  expect(fusion.decide(now:now,distance:DistanceEvent(35,now.subtract(const Duration(seconds:2)))).level,DangerLevel.unknown);
 });
 test('high-confidence vision is a strong threat',(){
  final detections=[const Detection('درج',.9,.2,[.1,.2,.3,.8])];
  expect(fusion.decide(now:now,distance:DistanceEvent(250,now),detections:detections,detectedAt:now,languageCode:'ar').voice,'انتبه، يوجد درج أمامك');
  final threat=fusion.decide(now:now,distance:DistanceEvent(35,now),detections:detections,detectedAt:now);
  expect(threat.level,DangerLevel.special);expect(threat.command,'S');
 });
 test('fresh high-confidence vision alerts without distance',(){
  final result=fusion.decide(now:now,detections:[const Detection('chair',.8,.5,[0,0,1,1])],detectedAt:now);
  expect(result.command,'S');
  expect(result.level,DangerLevel.special);
  expect(result.voice,'Warning, there is a chair ahead');
  expect(fusion.decide(now:now,detections:[const Detection('كرسي',.8,.5,[0,0,1,1])],detectedAt:now,languageCode:'ar').voice,'انتبه، يوجد كرسي أمامك');
    expect(fusion.decide(now:now,detections:[const Detection('chair',.49,.5,[0,0,1,1])],detectedAt:now).level,DangerLevel.unknown);
 });
 test('old vision cannot trigger special',(){expect(fusion.decide(now:now,distance:DistanceEvent(300,now),detections:[const Detection('stairs',.9,.5,[0,0,1,1])],detectedAt:now.subtract(const Duration(seconds:3))).level,DangerLevel.safe);});
}
