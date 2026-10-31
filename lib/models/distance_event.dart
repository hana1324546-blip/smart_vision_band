class DistanceEvent {
  final double cm;
  final DateTime received;
  const DistanceEvent(this.cm, this.received);
}
class Protocol {
  static MapEntry<String, double>? parse(String line) {
    final p = line.trim().split(':');
    if (p.length != 2) return null;
    final n = double.tryParse(p[1]);
    if (n == null || !n.isFinite) return null;
    if (p[0] == 'DIST' && n > 0 && n <= 600) return MapEntry('DIST', n);
    if (p[0] == 'BATT' && n >= 0 && n <= 100) return MapEntry('BATT', n);
    return null;
  }
}
