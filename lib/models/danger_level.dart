enum DangerLevel { unknown, safe, caution, warning, danger, special }
class Decision {
  final DangerLevel level;
  final String command, voice;
  const Decision(this.level, this.command, this.voice);
}
