import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:strava_client/strava_client.dart';
import '../utils/db_utils.dart';

class AthleteModel {
  static final AthleteModel _instance = AthleteModel._internal();
  factory AthleteModel() => _instance;

  AthleteModel._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'athlete.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE athlete(
            id INTEGER PRIMARY KEY,
            resource_state INTEGER,
            firstname TEXT,
            lastname TEXT,
            profile_medium TEXT,
            profile TEXT,
            city TEXT,
            state TEXT,
            country TEXT,
            sex TEXT,
            summit BOOLEAN,
            created_at TEXT,
            updated_at TEXT,
            follower_count INTEGER,
            friend_count INTEGER,
            measurement_preference TEXT,
            ftp INTEGER,
            weight REAL,
            last_sync_time TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveAthlete(DetailedAthlete athlete) async {
    final db = await database;
    final athleteMap = {
      'id': athlete.id,
      'resource_state': athlete.resourceState,
      'firstname': athlete.firstname ?? '',
      'lastname': athlete.lastname ?? '',
      'profile_medium': athlete.profileMedium ?? '',
      'profile': athlete.profile ?? '',
      'city': athlete.city ?? '',
      'state': athlete.state ?? '',
      'country': athlete.country ?? '',
      'sex': athlete.sex ?? '',
      'summit': athlete.premium ? 1 : 0,
      'created_at': athlete.createdAt,
      'updated_at': athlete.updatedAt,
      'follower_count': athlete.followerCount ?? 0,
      'friend_count': athlete.friendCount ?? 0,
      'measurement_preference': athlete.measurementPreference ?? '',
      'ftp': athlete.ftp ?? 0,
      'weight': athlete.weight ?? 0.0,
      'last_sync_time': DateTime.now(),
    };

    // 使用DbUtils安全地执行插入操作
    await DbUtils.safeInsert(
      db,
      'athlete',
      athleteMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAthlete() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('athlete');
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<String?> getLastSyncTime() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'athlete',
      columns: ['last_sync_time'],
      limit: 1,
    );
    if (maps.isNotEmpty && maps.first['last_sync_time'] != null) {
      return maps.first['last_sync_time'] as String;
    }
    return null;
  }

  Future<void> updateLastSyncTime() async {
    try {
      final db = await database;
      final now = DateTime.now();

      // 首先检查是否有记录
      final List<Map<String, dynamic>> count =
          await db.rawQuery('SELECT COUNT(*) as count FROM athlete');

      if (count.isNotEmpty && (count.first['count'] as int) > 0) {
        // 使用DbUtils安全地执行更新操作
        await DbUtils.safeUpdate(
          db,
          'athlete',
          {'last_sync_time': now},
          where: 'id > ?',
          whereArgs: [0],
        );
      } else {
        print('没有运动员记录可更新，跳过更新最后同步时间');
      }
    } catch (e) {
      print('更新最后同步时间失败: $e');
      rethrow;
    }
  }

  Future<void> deleteAthlete() async {
    final db = await database;
    await db.delete('athlete');
  }
}
