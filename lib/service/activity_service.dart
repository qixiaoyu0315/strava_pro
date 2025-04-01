import 'package:strava_client/strava_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'strava_client_manager.dart';
import '../utils/logger.dart';

/// 活动服务类，处理活动数据的同步和存储
class ActivityService {
  static Database? _database;
  static const String tableName = 'activities';
  static const String syncTableName = 'sync_status';
  static const int _databaseVersion = 2; // 增加数据库版本号
  
  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// 初始化数据库
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'strava_activities.db');
    Logger.d('初始化数据库: $path', tag: 'ActivityService');
    
    // 检查数据库是否存在
    bool exists = await databaseExists(path);
    if (!exists) {
      Logger.d('数据库不存在，创建新数据库', tag: 'ActivityService');
    } else {
      Logger.d('数据库已存在，可能需要升级', tag: 'ActivityService');
    }
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    Logger.d('创建活动数据表 (数据库版本: $version)', tag: 'ActivityService');
    
    // 创建活动表
    await db.execute('''
      CREATE TABLE $tableName(
        id INTEGER PRIMARY KEY,
        activity_id TEXT UNIQUE,
        name TEXT,
        type TEXT,
        sport_type TEXT,
        start_date TEXT,
        elapsed_time INTEGER,
        moving_time INTEGER,
        distance REAL,
        total_elevation_gain REAL,
        average_speed REAL,
        max_speed REAL,
        average_heartrate REAL,
        max_heartrate INTEGER,
        average_cadence REAL,
        average_watts REAL,
        max_watts INTEGER,
        calories REAL,
        description TEXT,
        trainer BOOLEAN,
        commute BOOLEAN,
        manual BOOLEAN,
        private BOOLEAN,
        device_name TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 创建同步状态表
    await db.execute('''
      CREATE TABLE $syncTableName(
        id INTEGER PRIMARY KEY,
        last_page INTEGER DEFAULT 0,
        last_sync_time TEXT,
        athlete_created_at TEXT,
        total_activities INTEGER DEFAULT 0
      )
    ''');
    
    // 初始化同步状态
    await db.insert(syncTableName, {
      'last_page': 0,
      'last_sync_time': DateTime.now().toIso8601String(),
      'athlete_created_at': null,
      'total_activities': 0
    });
    
    Logger.d('活动数据表和同步状态表创建完成', tag: 'ActivityService');
  }
  
  /// 升级数据库
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.d('升级数据库从 $oldVersion 到 $newVersion', tag: 'ActivityService');
    
    if (oldVersion < 2) {
      // 版本1升级到版本2：添加同步状态表
      try {
        // 检查表是否已存在
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'"
        );
        
        if (tables.isEmpty) {
          Logger.d('创建同步状态表 $syncTableName', tag: 'ActivityService');
          
          // 创建同步状态表
          await db.execute('''
            CREATE TABLE $syncTableName(
              id INTEGER PRIMARY KEY,
              last_page INTEGER DEFAULT 0,
              last_sync_time TEXT,
              athlete_created_at TEXT,
              total_activities INTEGER DEFAULT 0
            )
          ''');
          
          // 初始化同步状态
          await db.insert(syncTableName, {
            'last_page': 0,
            'last_sync_time': DateTime.now().toIso8601String(),
            'athlete_created_at': null,
            'total_activities': 0
          });
          
          Logger.d('同步状态表创建完成', tag: 'ActivityService');
        } else {
          Logger.d('同步状态表已存在，跳过创建', tag: 'ActivityService');
        }
      } catch (e) {
        Logger.e('创建同步状态表失败: $e', error: e, tag: 'ActivityService');
        // 尝试直接删除旧表并重新创建
        try {
          await db.execute('DROP TABLE IF EXISTS $syncTableName');
          
          await db.execute('''
            CREATE TABLE $syncTableName(
              id INTEGER PRIMARY KEY,
              last_page INTEGER DEFAULT 0,
              last_sync_time TEXT,
              athlete_created_at TEXT,
              total_activities INTEGER DEFAULT 0
            )
          ''');
          
          // 初始化同步状态
          await db.insert(syncTableName, {
            'last_page': 0,
            'last_sync_time': DateTime.now().toIso8601String(),
            'athlete_created_at': null,
            'total_activities': 0
          });
          
          Logger.d('同步状态表重新创建完成', tag: 'ActivityService');
        } catch (e2) {
          Logger.e('重新创建同步状态表失败: $e2', error: e2, tag: 'ActivityService');
        }
      }
    }
  }

  /// 重置数据库
  Future<void> resetDatabase() async {
    try {
      Logger.d('开始重置数据库', tag: 'ActivityService');
      
      String path = join(await getDatabasesPath(), 'strava_activities.db');
      
      // 关闭数据库连接
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      // 删除数据库文件
      await deleteDatabase(path);
      Logger.d('数据库文件已删除', tag: 'ActivityService');
      
      // 重新初始化数据库
      _database = await _initDatabase();
      Logger.d('数据库已重新初始化', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('重置数据库失败: $e', error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }

  /// 更新运动员创建时间
  Future<void> updateAthleteCreatedAt(String createdAt) async {
    try {
      final db = await database;
      Logger.d('更新运动员创建时间: $createdAt', tag: 'ActivityService');
      
      // 检查同步状态表是否有记录
      final records = await db.query(syncTableName);
      if (records.isEmpty) {
        // 如果没有记录，初始化一条
        await db.insert(syncTableName, {
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': createdAt,
          'total_activities': 0
        });
      } else {
        // 更新已有记录
        await db.update(
          syncTableName,
          {'athlete_created_at': createdAt},
          where: 'id = ?',
          whereArgs: [records.first['id']],
        );
      }
    } catch (e, stackTrace) {
      Logger.e('更新运动员创建时间失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }

  /// 获取同步状态
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final db = await database;
      final records = await db.query(syncTableName);
      if (records.isEmpty) {
        // 如果没有记录，初始化一条
        final id = await db.insert(syncTableName, {
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': null,
          'total_activities': 0
        });
        return {
          'id': id,
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': null,
          'total_activities': 0
        };
      }
      return records.first;
    } catch (e, stackTrace) {
      Logger.e('获取同步状态失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }

  /// 更新同步状态
  Future<void> updateSyncStatus(int page, int totalActivities) async {
    try {
      final db = await database;
      final syncStatus = await getSyncStatus();
      
      await db.update(
        syncTableName,
        {
          'last_page': page,
          'last_sync_time': DateTime.now().toIso8601String(),
          'total_activities': totalActivities
        },
        where: 'id = ?',
        whereArgs: [syncStatus['id']],
      );
      
      Logger.d('更新同步状态：页数=$page, 总活动数=$totalActivities', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('更新同步状态失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 同步活动数据
  Future<void> syncActivities() async {
    try {
      Logger.d('开始同步活动数据', tag: 'ActivityService');
      
      // 检查同步状态表是否存在
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'"
      );
      
      if (tables.isEmpty) {
        Logger.d('同步状态表不存在，进行数据库升级', tag: 'ActivityService');
        await resetDatabase();
      }
      
      // 获取同步状态
      final syncStatus = await getSyncStatus();
      int currentPage = (syncStatus['last_page'] as int?) ?? 0;
      currentPage++; // 从下一页开始
      
      // 获取总活动数
      final activities = await db.query(tableName);
      int totalActivities = activities.length;
      
      Logger.d('当前同步状态: 页数=$currentPage, 总活动数=$totalActivities', tag: 'ActivityService');
      
      // 使用当前时间作为结束时间
      final now = DateTime.now().toUtc();
      
      // 获取运动员创建时间作为起始时间
      DateTime startTime;
      if (syncStatus['athlete_created_at'] != null) {
        startTime = DateTime.parse(syncStatus['athlete_created_at'].toString());
        Logger.d('使用运动员创建时间作为起始时间: ${startTime.toIso8601String()}', tag: 'ActivityService');
      } else {
        // 如果没有运动员创建时间，使用三年前的时间
        startTime = now.subtract(const Duration(days: 365 * 3));
        Logger.d('未找到运动员创建时间，使用三年前时间: ${startTime.toIso8601String()}', tag: 'ActivityService');
      }
      
      bool hasMoreActivities = true;
      int perPage = 50; // 每页30条数据
      int successCount = 0;
      int errorCount = 0;
      
      // 循环获取活动数据，直到没有更多数据
      while (hasMoreActivities) {
        Logger.d('获取第 $currentPage 页活动数据，每页 $perPage 条', tag: 'ActivityService');
        
        try {
          // 获取活动列表
          final pageActivities = await StravaClientManager()
              .stravaClient
              .activities
              .listLoggedInAthleteActivities(
                now,
                startTime,
                currentPage,
                perPage,
              );
          
          if (pageActivities.isEmpty) {
            Logger.d('第 $currentPage 页没有活动数据，同步完成', tag: 'ActivityService');
            hasMoreActivities = false;
            break;
          }
          
          Logger.d('从 Strava API 获取到第 $currentPage 页的 ${pageActivities.length} 个活动', 
              tag: 'ActivityService');
              
          for (var activity in pageActivities) {
            try {
              // 获取详细活动信息
              Logger.d('获取活动 ${activity.id} 的详细信息', tag: 'ActivityService');
              final detailedActivity = await StravaClientManager()
                  .stravaClient
                  .activities
                  .getActivity(activity.id!);
                  
              await _insertOrUpdateActivity(db, detailedActivity);
              successCount++;
              totalActivities = await _getActivityCount(db);
              
              // 每处理5个活动，更新一次同步状态
              if (successCount % 5 == 0) {
                await updateSyncStatus(currentPage, totalActivities);
              }
              
              Logger.d('成功保存活动 ${activity.id} 到数据库', tag: 'ActivityService');
            } catch (e) {
              errorCount++;
              Logger.e('处理活动 ${activity.id} 时出错: ${e.toString()}', error: e, tag: 'ActivityService');
            }
          }
          
          // 更新当前页码和同步状态
          await updateSyncStatus(currentPage, totalActivities);
          currentPage++;
          
        } catch (e) {
          Logger.e('获取第 $currentPage 页活动数据失败: ${e.toString()}', error: e, tag: 'ActivityService');
          // 发生错误时，保存当前同步状态，以便下次从这里继续
          await updateSyncStatus(currentPage - 1, totalActivities);
          throw Exception('获取第 $currentPage 页活动数据失败: ${e.toString()}');
        }
      }
      
      // 验证同步结果
      totalActivities = await _getActivityCount(db);
      Logger.d('同步完成，成功: $successCount, 失败: $errorCount, 数据库中现有 $totalActivities 个活动', 
          tag: 'ActivityService');
      
      // 更新最终的同步状态
      await updateSyncStatus(currentPage - 1, totalActivities);
          
      if (errorCount > 0) {
        throw Exception('同步过程中有 $errorCount 个活动处理失败');
      }
    } catch (e, stackTrace) {
      Logger.e('同步活动数据失败: ${e.toString()}', error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 获取活动总数
  Future<int> _getActivityCount(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
  
  /// 插入或更新活动数据
  Future<void> _insertOrUpdateActivity(Database db, DetailedActivity activity) async {
    try {
      Logger.d('准备保存活动 ${activity.id} 到数据库', tag: 'ActivityService');
      
      // 确保所有必需字段都有值
      if (activity.id == null) {
        throw Exception('活动ID不能为空');
      }
      
      final values = {
        'activity_id': activity.id.toString(),
        'name': activity.name ?? '未命名活动',
        'type': activity.type ?? '未知类型',
        'sport_type': activity.type ?? '未知类型', // 使用type作为sport_type
        'start_date': activity.startDateLocal ?? DateTime.now().toIso8601String(),
        'elapsed_time': activity.elapsedTime ?? 0,
        'moving_time': activity.movingTime ?? 0,
        'distance': activity.distance ?? 0.0,
        'total_elevation_gain': activity.totalElevationGain ?? 0.0,
        'average_speed': activity.averageSpeed ?? 0.0,
        'max_speed': activity.maxSpeed ?? 0.0,
        'average_heartrate': null, // 暂时设置为 null
        'max_heartrate': null, // 暂时设置为 null
        'average_cadence': activity.averageCadence ?? 0.0,
        'average_watts': activity.averageWatts ?? 0.0,
        'max_watts': activity.maxWatts ?? 0,
        'calories': activity.calories ?? 0.0,
        'description': activity.description ?? '',
        'trainer': activity.trainer ?? false ? 1 : 0,
        'commute': activity.commute ?? false ? 1 : 0,
        'manual': activity.manual ?? false ? 1 : 0,
        'private': activity.private ?? false ? 1 : 0,
        'device_name': activity.deviceName ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      final result = await db.insert(
        tableName,
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      Logger.d('活动 ${activity.id} 保存成功，结果: $result', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('保存活动 ${activity.id} 到数据库失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 获取所有活动数据
  Future<List<Map<String, dynamic>>> getAllActivities() async {
    try {
      Logger.d('开始获取所有活动数据', tag: 'ActivityService');
      final db = await database;
      final activities = await db.query(tableName, orderBy: 'start_date DESC');
      Logger.d('从数据库获取到 ${activities.length} 个活动', tag: 'ActivityService');
      return activities;
    } catch (e, stackTrace) {
      Logger.e('获取所有活动数据失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 获取单个活动数据
  Future<Map<String, dynamic>?> getActivity(String activityId) async {
    try {
      Logger.d('开始获取活动 $activityId 的数据', tag: 'ActivityService');
      final db = await database;
      final List<Map<String, dynamic>> results = await db.query(
        tableName,
        where: 'activity_id = ?',
        whereArgs: [activityId],
      );
      Logger.d('查询结果: ${results.isNotEmpty ? '找到活动' : '未找到活动'}', tag: 'ActivityService');
      return results.isNotEmpty ? results.first : null;
    } catch (e, stackTrace) {
      Logger.e('获取活动 $activityId 数据失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 删除活动数据
  Future<void> deleteActivity(String activityId) async {
    try {
      Logger.d('开始删除活动 $activityId', tag: 'ActivityService');
      final db = await database;
      final result = await db.delete(
        tableName,
        where: 'activity_id = ?',
        whereArgs: [activityId],
      );
      Logger.d('删除活动 $activityId 完成，结果: $result', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('删除活动 $activityId 失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
  
  /// 清空所有活动数据
  Future<void> clearAllActivities() async {
    try {
      Logger.d('开始清空所有活动数据', tag: 'ActivityService');
      final db = await database;
      final result = await db.delete(tableName);
      Logger.d('清空活动数据完成，结果: $result', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('清空活动数据失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }

  /// 重置同步状态
  Future<void> resetSyncStatus() async {
    try {
      Logger.d('重置同步状态', tag: 'ActivityService');
      final db = await database;
      
      // 检查表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'"
      );
      
      if (tables.isEmpty) {
        // 表不存在，创建表
        await db.execute('''
          CREATE TABLE $syncTableName(
            id INTEGER PRIMARY KEY,
            last_page INTEGER DEFAULT 0,
            last_sync_time TEXT,
            athlete_created_at TEXT,
            total_activities INTEGER DEFAULT 0
          )
        ''');
        
        // 初始化记录
        await db.insert(syncTableName, {
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': null,
          'total_activities': 0
        });
        
        Logger.d('同步状态表创建并初始化', tag: 'ActivityService');
      } else {
        // 表存在，获取记录修改
        final syncStatus = await getSyncStatus();
        
        await db.update(
          syncTableName,
          {
            'last_page': 0,
            'last_sync_time': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [syncStatus['id']],
        );
        
        Logger.d('同步状态已重置', tag: 'ActivityService');
      }
    } catch (e, stackTrace) {
      Logger.e('重置同步状态失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
  }
} 