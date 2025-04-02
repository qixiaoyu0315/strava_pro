import 'package:strava_client/strava_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'strava_client_manager.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:convert';

/// 活动服务类，处理活动数据的同步和存储
class ActivityService {
  static Database? _database;
  static const String tableName = 'activities';
  static const String syncTableName = 'sync_status';
  static const int _databaseVersion = 4; // 数据库版本更新为4
  
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
        activity_id INTEGER UNIQUE,
        resource_state INTEGER,
        name TEXT,
        distance REAL,
        moving_time INTEGER,
        elapsed_time INTEGER,
        total_elevation_gain REAL,
        type TEXT,
        workout_type INTEGER,
        external_id TEXT,
        upload_id INTEGER,
        start_date TEXT,
        start_date_local TEXT,
        timezone TEXT,
        utc_offset REAL,
        start_latlng TEXT,
        end_latlng TEXT,
        location_city TEXT,
        location_state TEXT,
        location_country TEXT,
        achievement_count INTEGER,
        kudos_count INTEGER,
        comment_count INTEGER,
        athlete_count INTEGER,
        photo_count INTEGER,
        map_id TEXT,
        map_polyline TEXT,
        map_resource_state INTEGER,
        athlete_id INTEGER,
        trainer BOOLEAN,
        commute BOOLEAN,
        manual BOOLEAN,
        private BOOLEAN,
        flagged BOOLEAN,
        gear_id TEXT,
        from_accepted_tag BOOLEAN,
        average_speed REAL,
        max_speed REAL,
        average_cadence REAL,
        average_watts REAL,
        weighted_average_watts INTEGER,
        kilojoules REAL,
        device_watts BOOLEAN,
        has_heartrate BOOLEAN,
        average_heartrate REAL,
        max_heartrate INTEGER,
        max_watts INTEGER,
        pr_count INTEGER,
        total_photo_count INTEGER,
        has_kudoed BOOLEAN,
        suffer_score REAL,
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
    
    // 版本2升级到版本3：更新活动表结构
    if (oldVersion < 3 && newVersion >= 3) {
      try {
        Logger.d('更新活动表结构到版本3', tag: 'ActivityService');
        
        // 备份旧表数据
        final oldActivities = await db.query(tableName);
        Logger.d('已备份 ${oldActivities.length} 条旧活动数据', tag: 'ActivityService');
        
        // 重命名旧表
        await db.execute('ALTER TABLE $tableName RENAME TO ${tableName}_old');
        
        // 创建新表
        await db.execute('''
          CREATE TABLE $tableName(
            id INTEGER PRIMARY KEY,
            activity_id INTEGER UNIQUE,
            resource_state INTEGER,
            name TEXT,
            distance REAL,
            moving_time INTEGER,
            elapsed_time INTEGER,
            total_elevation_gain REAL,
            type TEXT,
            workout_type INTEGER,
            external_id TEXT,
            upload_id INTEGER,
            start_date TEXT,
            start_date_local TEXT,
            timezone TEXT,
            utc_offset REAL,
            start_latlng TEXT,
            end_latlng TEXT,
            location_city TEXT,
            location_state TEXT,
            location_country TEXT,
            achievement_count INTEGER,
            kudos_count INTEGER,
            comment_count INTEGER,
            athlete_count INTEGER,
            photo_count INTEGER,
            map_id TEXT,
            map_polyline TEXT,
            map_resource_state INTEGER,
            athlete_id INTEGER,
            trainer BOOLEAN,
            commute BOOLEAN,
            manual BOOLEAN,
            private BOOLEAN,
            flagged BOOLEAN,
            gear_id TEXT,
            from_accepted_tag BOOLEAN,
            average_speed REAL,
            max_speed REAL,
            average_cadence REAL,
            average_watts REAL,
            weighted_average_watts INTEGER,
            kilojoules REAL,
            device_watts BOOLEAN,
            has_heartrate BOOLEAN,
            average_heartrate REAL,
            max_heartrate INTEGER,
            max_watts INTEGER,
            pr_count INTEGER,
            total_photo_count INTEGER,
            has_kudoed BOOLEAN,
            suffer_score REAL,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        
        // 迁移能够迁移的数据
        if (oldActivities.isNotEmpty) {
          Logger.d('开始迁移活动数据', tag: 'ActivityService');
          int migratedCount = 0;
          
          for (var oldActivity in oldActivities) {
            try {
              // 创建适合新表结构的数据
              var newActivity = {
                'activity_id': int.tryParse(oldActivity['activity_id'].toString()),
                'name': oldActivity['name'],
                'distance': oldActivity['distance'],
                'moving_time': oldActivity['moving_time'],
                'elapsed_time': oldActivity['elapsed_time'],
                'total_elevation_gain': oldActivity['total_elevation_gain'],
                'type': oldActivity['type'],
                'start_date': oldActivity['start_date'],
                'start_date_local': oldActivity['start_date_local'],
                'trainer': oldActivity['trainer'],
                'commute': oldActivity['commute'],
                'manual': oldActivity['manual'],
                'private': oldActivity['private'],
                'average_speed': oldActivity['average_speed'],
                'max_speed': oldActivity['max_speed'],
                'average_cadence': oldActivity['average_cadence'],
                'average_watts': oldActivity['average_watts'],
                'average_heartrate': oldActivity['average_heartrate'],
                'max_heartrate': oldActivity['max_heartrate'],
                'max_watts': oldActivity['max_watts'],
                'created_at': oldActivity['created_at'],
                'updated_at': DateTime.now().toIso8601String(),
              };
              
              // 移除空值
              newActivity.removeWhere((key, value) => value == null);
              
              // 插入新表
              await db.insert(tableName, newActivity);
              migratedCount++;
            } catch (e) {
              Logger.e('迁移活动 ID ${oldActivity['activity_id']} 失败: $e', error: e, tag: 'ActivityService');
            }
          }
          
          Logger.d('成功迁移 $migratedCount/${oldActivities.length} 条活动数据', tag: 'ActivityService');
        }
        
        // 删除旧表
        await db.execute('DROP TABLE IF EXISTS ${tableName}_old');
        Logger.d('已删除旧活动表', tag: 'ActivityService');
        
      } catch (e) {
        Logger.e('更新活动表结构失败: $e', error: e, tag: 'ActivityService');
        // 如果更新失败，尝试重置整个数据库
        try {
          String path = join(await getDatabasesPath(), 'strava_activities.db');
          await deleteDatabase(path);
          Logger.w('数据库更新失败，已重置数据库', tag: 'ActivityService');
        } catch (e2) {
          Logger.e('重置数据库失败: $e2', error: e2, tag: 'ActivityService');
        }
      }
    }
    
    // 版本3升级到版本4：添加复杂类型字段
    if (oldVersion < 4 && newVersion >= 4) {
      try {
        Logger.d('更新活动表结构到版本4 - 添加复杂类型字段', tag: 'ActivityService');
        
        // 添加新列
        final columnUpdateStatements = [
          'ALTER TABLE $tableName ADD COLUMN start_latlng TEXT',
          'ALTER TABLE $tableName ADD COLUMN end_latlng TEXT',
          'ALTER TABLE $tableName ADD COLUMN map_id TEXT',
          'ALTER TABLE $tableName ADD COLUMN map_polyline TEXT',
          'ALTER TABLE $tableName ADD COLUMN map_resource_state INTEGER',
          'ALTER TABLE $tableName ADD COLUMN athlete_id INTEGER',
        ];
        
        // 执行列添加操作
        for (var statement in columnUpdateStatements) {
          try {
            await db.execute(statement);
            Logger.d('执行成功: $statement', tag: 'ActivityService');
          } catch (e) {
            // 列可能已存在，忽略错误
            Logger.w('执行失败: $statement, 错误: $e', tag: 'ActivityService');
          }
        }
        
        Logger.d('活动表结构更新到版本4完成', tag: 'ActivityService');
      } catch (e) {
        Logger.e('更新活动表结构到版本4失败: $e', error: e, tag: 'ActivityService');
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
      Logger.d('获取同步状态', tag: 'ActivityService');
      final db = await database;
      
      // 确保同步状态表存在
      bool syncTableExists = await _ensureSyncTableExists(db);
      if (!syncTableExists) {
        Logger.d('同步状态表不存在，创建表', tag: 'ActivityService');
        await resetSyncStatus();
      }
      
      final List<Map<String, dynamic>> results = await db.query(syncTableName);
      
      if (results.isEmpty) {
        Logger.d('同步状态记录不存在，创建记录', tag: 'ActivityService');
        
        // 创建默认记录
        final defaultStatus = {
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': null,
          'total_activities': 0
        };
        
        final id = await db.insert(syncTableName, defaultStatus);
        defaultStatus['id'] = id;
        
        return defaultStatus;
      }
      
      Logger.d('同步状态: ${results.first}', tag: 'ActivityService');
      return results.first;
    } catch (e, stackTrace) {
      Logger.e('获取同步状态失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      // 出错时返回一个默认状态
      return {
        'id': 1,
        'last_page': 0,
        'last_sync_time': DateTime.now().toIso8601String(),
        'athlete_created_at': null,
        'total_activities': 0
      };
    }
  }

  /// 更新同步状态
  Future<void> updateSyncStatus(int currentPage, int totalActivities) async {
    try {
      Logger.d('更新同步状态: 页数=$currentPage, 总活动数=$totalActivities', tag: 'ActivityService');
      final db = await database;
      
      // 获取当前同步状态
      final status = await getSyncStatus();
      
      // 更新同步状态
      await db.update(
        syncTableName,
        {
          'last_page': currentPage,
          'last_sync_time': DateTime.now().toIso8601String(),
          'total_activities': totalActivities
        },
        where: 'id = ?',
        whereArgs: [status['id']],
      );
      
      Logger.d('同步状态更新完成', tag: 'ActivityService');
    } catch (e, stackTrace) {
      Logger.e('更新同步状态失败: ${e.toString()}', 
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
      // 更新失败不抛出异常，继续同步过程
    }
  }
  
  /// 同步活动数据
  Future<void> syncActivities({
    Function(double current, double total, String status)? onProgress
  }) async {
    try {
      Logger.d('开始同步活动数据 - 使用摘要数据模式', tag: 'ActivityService');
      final db = await database;
      
      // 确保数据库表存在
      bool syncTableExists = await _ensureSyncTableExists(db);
      if (!syncTableExists) {
        Logger.d('同步状态表不存在，尝试重置数据库', tag: 'ActivityService');
        // 如果表不存在，可能是因为数据库版本问题，尝试重置数据库
        await resetDatabase();
        // 获取新的数据库连接
        final newDb = await database;
        syncTableExists = await _ensureSyncTableExists(newDb);
        if (!syncTableExists) {
          throw Exception('无法创建同步状态表');
        }
      }
      
      // 获取同步状态
      final syncStatusList = await db.query(syncTableName);
      Map<String, dynamic> syncStatus;
      
      if (syncStatusList.isEmpty) {
        Logger.d('同步状态不存在，初始化同步状态', tag: 'ActivityService');
        syncStatus = {
          'last_page': 0,
          'last_sync_time': DateTime.now().toIso8601String(),
          'athlete_created_at': null,
          'total_activities': 0
        };
        await db.insert(syncTableName, syncStatus);
      } else {
        syncStatus = syncStatusList.first;
      }
      
      int currentPage = (syncStatus['last_page'] as int?) ?? 0;
      currentPage++; // 从下一页开始
      
      // 获取总活动数
      final activities = await db.query(tableName);
      int totalActivities = activities.length;
      int initialActivityCount = totalActivities;
      
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
      int perPage = 50; // 每页50条数据
      int successCount = 0;
      int errorCount = 0;
      int totalPages = 0;
      Stopwatch stopwatch = Stopwatch()..start();
      
      // 循环获取活动数据，直到没有更多数据
      while (hasMoreActivities) {
        totalPages++;
        Logger.d('获取第 $currentPage 页活动数据，每页 $perPage 条', tag: 'ActivityService');
        
        // 更新进度
        if (onProgress != null) {
          onProgress(successCount.toDouble(), 
                    (successCount + perPage).toDouble(), 
                    '获取第 $currentPage 页活动数据...');
        }
        
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
          
          int pageSuccessCount = 0;
          int pageErrorCount = 0;
              
          for (var activity in pageActivities) {
            try {
              // 直接保存 SummaryActivity 数据，不再获取详细信息
              if (successCount % 10 == 0) {
                Logger.d('处理活动 ${activity.id} - ${activity.name}', tag: 'ActivityService');
              }
              
              // 更新进度
              if (onProgress != null) {
                onProgress(successCount.toDouble(), 
                          (successCount + pageActivities.length).toDouble(), 
                          '处理活动: ${activity.name ?? activity.id}');
              }
              
              // 直接保存活动数据，不获取详细信息
              await _insertOrUpdateActivity(db, activity);
              successCount++;
              pageSuccessCount++;
              
              // 每处理10个活动，更新一次同步状态
              if (successCount % 10 == 0) {
                totalActivities = await _getActivityCount(db);
                await updateSyncStatus(currentPage, totalActivities);
                
                // 更新进度
                if (onProgress != null) {
                  onProgress(successCount.toDouble(), 
                            (successCount + (pageActivities.length - pageActivities.indexOf(activity) - 1)).toDouble(), 
                            '已同步 $successCount 个活动...');
                }
              }
            } catch (e) {
              errorCount++;
              pageErrorCount++;
              Logger.e('处理活动 ${activity.id} 时出错: ${e.toString()}', error: e, tag: 'ActivityService');
            }
          }
          
          Logger.d('第 $currentPage 页处理完成: 成功=$pageSuccessCount, 失败=$pageErrorCount', tag: 'ActivityService');
          
          // 更新当前页码和同步状态
          totalActivities = await _getActivityCount(db);
          await updateSyncStatus(currentPage, totalActivities);
          currentPage++;
          
        } catch (e) {
          Logger.e('获取第 $currentPage 页活动数据失败: ${e.toString()}', error: e, tag: 'ActivityService');
          // 发生错误时，保存当前同步状态，以便下次从这里继续
          await updateSyncStatus(currentPage - 1, totalActivities);
          throw Exception('获取第 $currentPage 页活动数据失败: ${e.toString()}');
        }
      }
      
      // 停止计时
      stopwatch.stop();
      int elapsedSeconds = stopwatch.elapsedMilliseconds ~/ 1000;
      
      // 验证同步结果
      totalActivities = await _getActivityCount(db);
      int newActivities = totalActivities - initialActivityCount;
      
      Logger.d('同步完成，耗时：${elapsedSeconds}秒，共处理 $successCount 个活动，新增 $newActivities 个，'
          '失败 $errorCount 个，共查询 $totalPages 页，数据库中现有 $totalActivities 个活动', 
          tag: 'ActivityService');
      
      // 最终更新进度
      if (onProgress != null) {
        onProgress(1.0, 1.0, '同步完成，共同步 $successCount 个活动，新增 $newActivities 个');
      }
      
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
  Future<void> _insertOrUpdateActivity(Database db, SummaryActivity activity) async {
    try {
      Logger.d('准备保存活动 ${activity.id} 到数据库', tag: 'ActivityService');
      
      // 确保所有必需字段都有值
      if (activity.id == null) {
        throw Exception('活动ID不能为空');
      }
      
      // 处理 startLatlng 和 endLatlng，将 List<double> 转为 JSON 字符串
      String? startLatlngJson;
      String? endLatlngJson;
      if (activity.startLatlng != null && activity.startLatlng!.isNotEmpty) {
        startLatlngJson = jsonEncode(activity.startLatlng);
      }
      if (activity.endLatlng != null && activity.endLatlng!.isNotEmpty) {
        endLatlngJson = jsonEncode(activity.endLatlng);
      }
      
      // 处理 map 对象，提取有用信息
      String? mapId;
      String? mapPolyline;
      int? mapResourceState;
      if (activity.map != null) {
        mapId = activity.map!.id;
        mapPolyline = activity.map!.summaryPolyline;
        mapResourceState = activity.map!.resourceState;
      }
      
      // 处理 athlete 对象，提取 athleteId
      int? athleteId;
      if (activity.athlete != null) {
        athleteId = activity.athlete!.id;
      }
      
      final values = {
        'activity_id': activity.id,
        'resource_state': activity.resourceState,
        'name': activity.name ?? '未命名活动',
        'distance': activity.distance ?? 0.0,
        'moving_time': activity.movingTime ?? 0,
        'elapsed_time': activity.elapsedTime ?? 0,
        'total_elevation_gain': activity.totalElevationGain ?? 0.0,
        'type': activity.type ?? '未知类型',
        'workout_type': activity.workoutType,
        'external_id': activity.externalId,
        'upload_id': activity.uploadId,
        'start_date': activity.startDate,
        'start_date_local': activity.startDateLocal,
        'timezone': activity.timezone,
        'utc_offset': activity.utcOffset,
        'start_latlng': startLatlngJson,
        'end_latlng': endLatlngJson,
        'location_city': activity.locationCity,
        'location_state': activity.locationState,
        'location_country': activity.locationCountry,
        'achievement_count': activity.achievementCount,
        'kudos_count': activity.kudosCount,
        'comment_count': activity.commentCount,
        'athlete_count': activity.athleteCount,
        'photo_count': activity.photoCount,
        'map_id': mapId,
        'map_polyline': mapPolyline,
        'map_resource_state': mapResourceState,
        'athlete_id': athleteId,
        'trainer': activity.trainer == true ? 1 : 0,
        'commute': activity.commute == true ? 1 : 0,
        'manual': activity.manual == true ? 1 : 0,
        'private': activity.private == true ? 1 : 0,
        'flagged': activity.flagged == true ? 1 : 0,
        'gear_id': activity.gearId,
        'from_accepted_tag': activity.fromAcceptedTag == true ? 1 : 0,
        'average_speed': activity.averageSpeed ?? 0.0,
        'max_speed': activity.maxSpeed ?? 0.0,
        'average_cadence': activity.averageCadence,
        'average_watts': activity.averageWatts,
        'weighted_average_watts': activity.weightedAverageWatts,
        'kilojoules': activity.kilojoules,
        'device_watts': activity.deviceWatts == true ? 1 : 0,
        'has_heartrate': activity.hasHeartrate == true ? 1 : 0,
        'average_heartrate': activity.averageHeartrate,
        'max_heartrate': activity.maxHeartrate,
        'max_watts': activity.maxWatts,
        'pr_count': activity.prCount,
        'total_photo_count': activity.totalPhotoCount,
        'has_kudoed': activity.hasKudoed == true ? 1 : 0,
        'suffer_score': activity.sufferScore,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // 移除所有值为null的键
      values.removeWhere((key, value) => value == null);
      
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
      final db = await database;
      final result = await db.query(tableName, orderBy: 'start_date DESC');
      return result;
    } catch (e) {
      Logger.e('获取活动数据失败: $e', tag: 'ActivityService');
      return [];
    }
  }
  
  /// 按日期获取活动数据
  Future<List<Map<String, dynamic>>> getActivitiesByDate(String date) async {
    try {
      final db = await database;
      final result = await db.query(
        tableName,
        where: "start_date LIKE ?",
        whereArgs: ['$date%'],
      );
      return result;
    } catch (e) {
      Logger.e('按日期获取活动数据失败: $e', tag: 'ActivityService');
      return [];
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

  /// 确保同步状态表存在
  Future<bool> _ensureSyncTableExists(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'"
    );
    return tables.isNotEmpty;
  }
} 