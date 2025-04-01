import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:strava_client/strava_client.dart';
import '../utils/db_utils.dart';
import '../utils/logger.dart';
import 'dart:io';

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
      version: 2,
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
            last_sync_time TEXT,
            last_activity_sync_time TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE athlete ADD COLUMN last_activity_sync_time TEXT'
            );
            await db.execute(
              'UPDATE athlete SET last_activity_sync_time = last_sync_time'
            );
            Logger.d('数据库迁移成功：添加last_activity_sync_time列', tag: 'DatabaseMigration');
          } catch (e) {
            Logger.e('数据库迁移失败', error: e, tag: 'DatabaseMigration');
          }
        }
      },
    );
  }

  Future<void> saveAthlete(DetailedAthlete athlete) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
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
      'last_sync_time': now,
      'last_activity_sync_time': now,
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
      // 使用ISO8601字符串格式
      final now = DateTime.now().toUtc().toIso8601String();

      // 首先检查是否有记录
      final List<Map<String, dynamic>> count =
          await db.rawQuery('SELECT COUNT(*) as count FROM athlete');

      if (count.isNotEmpty && (count.first['count'] as int) > 0) {
        // 修改查询条件为id = 1，与其他方法保持一致
        await db.update(
          'athlete',
          {'last_sync_time': now},
          where: 'id = ?',
          whereArgs: [1],
        );
        Logger.d('更新最后同步时间成功: $now', tag: 'Database');
      } else {
        Logger.w('没有运动员记录可更新，跳过更新最后同步时间', tag: 'Database');
      }
    } catch (e) {
      Logger.e('更新最后同步时间失败', error: e, tag: 'Database');
      // 不要抛出异常，保持与updateLastActivitySyncTime一致的行为
    }
  }

  // 检查列是否存在
  Future<bool> _columnExists(Database db, String tableName, String columnName) async {
    var result = await db.rawQuery(
      "PRAGMA table_info($tableName)"
    );
    
    for (var column in result) {
      if (column['name'] == columnName) {
        return true;
      }
    }
    return false;
  }

  // 检查并创建活动同步时间列
  Future<void> _ensureLastActivitySyncTimeColumn() async {
    final db = await database;
    bool columnExists = await _columnExists(db, 'athlete', 'last_activity_sync_time');
    
    if (!columnExists) {
      try {
        await db.execute(
          'ALTER TABLE athlete ADD COLUMN last_activity_sync_time TEXT'
        );
        // 将现有记录的last_activity_sync_time设置为与last_sync_time相同
        await db.execute(
          'UPDATE athlete SET last_activity_sync_time = last_sync_time'
        );
        Logger.d('添加last_activity_sync_time列成功', tag: 'Database');
      } catch (e) {
        Logger.e('添加last_activity_sync_time列失败', error: e, tag: 'Database');
      }
    }
  }

  Future<void> updateLastActivitySyncTime() async {
    try {
      final db = await database;
      
      // 先检查表中是否有这个字段
      bool columnExists = await _columnExists(db, 'athlete', 'last_activity_sync_time');
      if (!columnExists) {
        Logger.w('last_activity_sync_time列不存在，尝试添加', tag: 'Database');
        try {
          await db.execute('ALTER TABLE athlete ADD COLUMN last_activity_sync_time TEXT');
          Logger.d('成功添加last_activity_sync_time列', tag: 'Database');
        } catch (e) {
          Logger.e('添加last_activity_sync_time列失败', error: e, tag: 'Database');
        }
      }
      
      final now = DateTime.now().toUtc().toIso8601String();
      Logger.d('准备更新最后活动同步时间: $now', tag: 'Database');
      
      // 获取记录条数
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM athlete');
      int count = countResult.first['count'] as int;
      Logger.d('athlete表中有$count条记录', tag: 'Database');
      
      if (count > 0) {
        // 获取当前记录的ID
        final records = await db.query('athlete', columns: ['id']);
        if (records.isNotEmpty) {
          int recordId = records.first['id'] as int;
          Logger.d('找到记录ID: $recordId', tag: 'Database');
          
          // 更新
          int updated = await db.rawUpdate(
            'UPDATE athlete SET last_activity_sync_time = ? WHERE id = ?',
            [now, recordId]
          );
          
          Logger.d('更新了$updated行，最后活动同步时间: $now', tag: 'Database');
          
          // 验证更新是否成功
          final verification = await db.query(
            'athlete',
            columns: ['last_activity_sync_time'],
            where: 'id = ?',
            whereArgs: [recordId]
          );
          
          if (verification.isNotEmpty) {
            String? updatedValue = verification.first['last_activity_sync_time'] as String?;
            Logger.d('验证更新结果: $updatedValue', tag: 'Database');
          } else {
            Logger.w('无法验证更新结果', tag: 'Database');
          }
        } else {
          Logger.w('无法获取记录ID', tag: 'Database');
        }
      } else {
        Logger.w('athlete表中没有记录，无法更新最后活动同步时间', tag: 'Database');
      }
    } catch (e) {
      Logger.e('更新最后活动同步时间失败', error: e, tag: 'Database');
    }
  }

  Future<String?> getLastActivitySyncTime() async {
    try {
      final db = await database;
      
      // 先检查表中是否有这个字段
      bool columnExists = await _columnExists(db, 'athlete', 'last_activity_sync_time');
      if (!columnExists) {
        Logger.w('获取失败：last_activity_sync_time列不存在', tag: 'Database');
        return null;
      }
      
      // 获取记录条数
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM athlete');
      int count = countResult.first['count'] as int;
      Logger.d('获取最后活动同步时间：athlete表中有$count条记录', tag: 'Database');
      
      if (count > 0) {
        final records = await db.query('athlete');
        if (records.isNotEmpty) {
          var record = records.first;
          Logger.d('获取到记录 ID: ${record['id']}', tag: 'Database');
          
          // 输出所有字段名和值用于调试
          record.forEach((key, value) {
            Logger.d('字段: $key, 值: $value', tag: 'Database');
          });
          
          var lastActivitySyncTime = record['last_activity_sync_time'];
          Logger.d('读取到的最后活动同步时间: $lastActivitySyncTime', tag: 'Database');
          
          return lastActivitySyncTime as String?;
        } else {
          Logger.w('athlete表中没有记录', tag: 'Database');
        }
      } else {
        Logger.w('athlete表为空', tag: 'Database');
      }
      
      return null;
    } catch (e) {
      Logger.e('获取最后活动同步时间失败', error: e, tag: 'Database');
      return null;
    }
  }

  Future<void> deleteAthlete() async {
    final db = await database;
    await db.delete('athlete');
  }

  // 调试方法：检查数据库表结构并输出
  Future<void> debugDatabaseTable() async {
    try {
      final db = await database;
      var tableInfo = await db.rawQuery("PRAGMA table_info(athlete)");
      
      Logger.d('athlete表结构:', tag: 'DatabaseDebug');
      for (var column in tableInfo) {
        Logger.d('列: ${column['name']}, 类型: ${column['type']}', tag: 'DatabaseDebug');
      }
      
      // 检查记录
      var records = await db.query('athlete');
      Logger.d('athlete表记录数: ${records.length}', tag: 'DatabaseDebug');
      
      if (records.isNotEmpty) {
        var record = records.first;
        Logger.d('第一条记录ID: ${record['id']}', tag: 'DatabaseDebug');
        Logger.d('last_sync_time: ${record['last_sync_time']}', tag: 'DatabaseDebug');
        Logger.d('last_activity_sync_time: ${record['last_activity_sync_time']}', tag: 'DatabaseDebug');
      }
    } catch (e) {
      Logger.e('调试数据库失败', error: e, tag: 'DatabaseDebug');
    }
  }

  // 修复方法：确保最后活动同步时间字段存在并有值
  Future<void> fixLastActivitySyncTime() async {
    try {
      final db = await database;
      await _ensureLastActivitySyncTimeColumn();
      
      // 检查是否有记录但last_activity_sync_time为空
      var records = await db.query(
        'athlete',
        columns: ['id', 'last_sync_time', 'last_activity_sync_time']
      );
      
      if (records.isNotEmpty) {
        var record = records.first;
        if (record['last_activity_sync_time'] == null) {
          // 如果last_activity_sync_time为空但last_sync_time有值
          if (record['last_sync_time'] != null) {
            await db.update(
              'athlete',
              {'last_activity_sync_time': record['last_sync_time']},
              where: 'id = ?',
              whereArgs: [record['id']],
            );
            Logger.d('已修复最后活动同步时间', tag: 'DatabaseFix');
          } else {
            // 如果两者都为空，设置为当前时间
            final now = DateTime.now().toUtc().toIso8601String();
            await db.update(
              'athlete',
              {'last_sync_time': now, 'last_activity_sync_time': now},
              where: 'id = ?',
              whereArgs: [record['id']],
            );
            Logger.d('已设置默认同步时间', tag: 'DatabaseFix');
          }
        } else {
          Logger.d('最后活动同步时间正常', tag: 'DatabaseFix');
        }
      } else {
        Logger.w('没有运动员记录，无需修复', tag: 'DatabaseFix');
      }
    } catch (e) {
      Logger.e('修复最后活动同步时间失败', error: e, tag: 'DatabaseFix');
    }
  }

  // 完全重置数据库
  Future<void> resetDatabase() async {
    try {
      _database = null; // 释放数据库连接
      
      // 获取数据库路径
      String path = join(await getDatabasesPath(), 'athlete.db');
      Logger.d('数据库路径: $path', tag: 'DatabaseReset');
      
      // 删除数据库文件
      File dbFile = File(path);
      if (await dbFile.exists()) {
        await dbFile.delete();
        Logger.d('数据库文件已删除', tag: 'DatabaseReset');
      }
      
      // 重新初始化数据库
      _database = await _initDB();
      Logger.d('数据库已重新初始化', tag: 'DatabaseReset');
      
      return;
    } catch (e) {
      Logger.e('重置数据库失败', error: e, tag: 'DatabaseReset');
    }
  }
}
