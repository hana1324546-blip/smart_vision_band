import '../models/detection.dart';
import '../models/distance_event.dart';
import '../models/danger_level.dart';

/// Pure decision function. Fresh ultrasonic data takes priority over vision.
/// UNKNOWN is not SAFE. A single beam does not measure every detected object.
class SensorFusionService {
  Decision decide({required DateTime now, DistanceEvent? distance,
        List<Detection> detections = const [], DateTime? detectedAt,
      double confidence = .5, String languageCode = 'en'}) {
    final isArabic = languageCode == 'ar';
    final freshDistance = distance != null &&
      now.difference(distance.received).inMilliseconds >= 0 &&
      now.difference(distance.received).inMilliseconds <= 1500;
    final freshVision = detectedAt != null &&
      now.difference(detectedAt).inMilliseconds >= 0 &&
      now.difference(detectedAt).inMilliseconds <= 1000;
    final valid = freshVision
      ? detections.where((d) => d.confidence >= confidence).toList()
      : <Detection>[];
    if (freshDistance && distance.cm < 30) {
      return Decision(DangerLevel.danger, 'S', isArabic
        ? 'انتبه، يوجد عائق قريب أمامك'
        : 'Warning, there is an obstacle ahead');
    }
    if (valid.isNotEmpty) {
      final detection = valid.reduce((a, b) => a.confidence >= b.confidence ? a : b);
      final label = detection.label;
      final lowerLabel = label.isEmpty ? 'obstacle' : '${label[0].toLowerCase()}${label.substring(1)}';
      final voice = isArabic
        ? 'انتبه، يوجد $label أمامك'
        : lowerLabel == 'stairs'
          ? 'Warning, there are stairs ahead'
          : 'Warning, there is ${_articleFor(lowerLabel)} $lowerLabel ahead';
      return Decision(DangerLevel.special, 'S', voice);
    }
    if (!freshDistance) return Decision(DangerLevel.unknown,
      'W', isArabic ? 'بيانات مستشعر المسافة غير متاحة' : 'Distance sensor unavailable');
    final cm = distance.cm;
    if (cm <= 60) return Decision(DangerLevel.warning,
      'W', isArabic ? 'انتبه، عائق قريب أمامك' : 'Warning, an obstacle is nearby');
    return const Decision(DangerLevel.safe, 'C', '');
  }

  String _articleFor(String label) => 'aeiou'.contains(label[0]) ? 'an' : 'a';
}
