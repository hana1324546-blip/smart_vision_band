class Detection {
  final String label;
  final double confidence, centerX;
  final List<double> bbox;
  const Detection(this.label, this.confidence, this.centerX, this.bbox);
  factory Detection.fromJson(Map<dynamic, dynamic> j) => Detection(
    j['class'] as String, (j['confidence'] as num).toDouble(),
    (j['centerX'] as num).toDouble(),
    (j['bbox'] as List).map((x) => (x as num).toDouble()).toList());
}
