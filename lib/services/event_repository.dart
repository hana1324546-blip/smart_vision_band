import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
class EventRepository {
  Database? _db;
  Future<Database> get db async => _db ??= await openDatabase(
    p.join(await getDatabasesPath(), 'smart_vision.db'), version: 1,
    onCreate: (d, _) async {
      await d.execute('CREATE TABLE events(id INTEGER PRIMARY KEY, timestamp INTEGER, obstacleClass TEXT, confidence REAL, distanceCm REAL, dangerLevel TEXT, hapticPattern TEXT, voiceAlertPlayed INTEGER, aiLatencyMs REAL)');
      await d.execute('CREATE INDEX event_time ON events(timestamp)');
      await d.execute('CREATE TABLE sessions(id INTEGER PRIMARY KEY, startTime INTEGER, endTime INTEGER, totalDetections INTEGER DEFAULT 0, totalAlerts INTEGER DEFAULT 0)');
    });
  Future<void> add(Map<String, Object?> row) async {
    final d = await db;
    await d.insert('events', row);
    await d.delete('events', where: 'timestamp < ?', whereArgs: [DateTime.now().subtract(const Duration(days:30)).millisecondsSinceEpoch]);
    // Logical cap in addition to age retention; maintenance compacts the file.
    await d.execute('DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY id DESC LIMIT 10000)');
  }
  Future<List<Map<String,Object?>>> recent() async => (await db).query('events', orderBy:'id DESC', limit: 200);
  Future<String> csv() async {
    final rows = await recent();
    const keys = ['timestamp','obstacleClass','confidence','distanceCm','dangerLevel','hapticPattern','voiceAlertPlayed','aiLatencyMs'];
    String quote(Object? x) => '"${(x ?? '').toString().replaceAll('"', '""')}"';
    return [keys.join(','), ...rows.map((r) => keys.map((k) => quote(r[k])).join(','))].join('\r\n');
  }
}
