import 'package:strava_client/strava_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'strava_client_manager.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/calendar_utils.dart';

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
            "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'");

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
                'activity_id':
                    int.tryParse(oldActivity['activity_id'].toString()),
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
              Logger.e('迁移活动 ID ${oldActivity['activity_id']} 失败: $e',
                  error: e, tag: 'ActivityService');
            }
          }

          Logger.d('成功迁移 $migratedCount/${oldActivities.length} 条活动数据',
              tag: 'ActivityService');
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
      Logger.e('重置数据库失败: $e',
          error: e, stackTrace: stackTrace, tag: 'ActivityService');
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
  Future<void> updateSyncStatus(
      {required int lastPage, required int totalActivities}) async {
    try {
      Logger.d('更新同步状态: 页数=$lastPage, 总活动数=$totalActivities',
          tag: 'ActivityService');
      final db = await database;

      // 获取当前同步状态
      final status = await getSyncStatus();

      // 更新同步状态
      await db.update(
        syncTableName,
        {
          'last_page': lastPage,
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
  Future<void> syncActivities(
      {Function(double current, double total, String status)?
          onProgress}) async {
    try {
      Logger.d('开始同步活动数据 - 使用全量同步模式', tag: 'ActivityService');
      final db = await database;

      // 确保数据库表存在
      bool syncTableExists = await _ensureSyncTableExists(db);
      if (!syncTableExists) {
        Logger.d('同步状态表不存在，尝试重置数据库', tag: 'ActivityService');
        await resetDatabase();
        final newDb = await database;
        syncTableExists = await _ensureSyncTableExists(newDb);
        if (!syncTableExists) {
          throw Exception('无法创建同步状态表');
        }
      }

      // 获取同步状态
      final syncStatus = await getSyncStatus();
      
      // 检查之前是否有同步失败导致的异常状态，如果存在，先重置同步状态
      if (syncStatus['last_page'] > 0) {
        Logger.d('检测到之前的同步状态，重置同步状态', tag: 'ActivityService');
        await resetSyncStatus();
      }

      // 使用当前时间作为结束时间
      final now = DateTime.now();

      // 获取运动员创建时间作为起始时间
      DateTime startTime;
      if (syncStatus['athlete_created_at'] != null) {
        startTime = DateTime.parse(syncStatus['athlete_created_at'].toString()).toLocal();
        Logger.d('使用运动员创建时间作为起始时间: ${startTime.toIso8601String()}',
            tag: 'ActivityService');
      } else {
        // 如果没有运动员创建时间，使用三年前的时间
        startTime = now.subtract(const Duration(days: 365 * 3));
        Logger.d('未找到运动员创建时间，使用三年前时间: ${startTime.toIso8601String()}',
            tag: 'ActivityService');
      }

      const perPage = 100;
      int currentPage = 1;
      int successCount = 0;
      int errorCount = 0;
      bool hasMoreActivities = true;
      Stopwatch stopwatch = Stopwatch()..start();

      // 获取数据库中最新的活动ID
      final latestDbActivity = await db.query(
        tableName,
        orderBy: 'activity_id DESC',
        limit: 1,
      );

      int? latestDbActivityId;
      if (latestDbActivity.isNotEmpty) {
        latestDbActivityId = latestDbActivity.first['activity_id'] as int;
        Logger.d('数据库中最新的活动ID: $latestDbActivityId', tag: 'ActivityService');
      }

      // 循环获取所有页面的活动
      while (hasMoreActivities) {
        Logger.d('获取第 $currentPage 页活动数据，每页 $perPage 条', tag: 'ActivityService');

        if (onProgress != null) {
          onProgress(
            (currentPage - 1) * perPage.toDouble(),
            currentPage * perPage.toDouble(),
            '获取第 $currentPage 页活动数据...',
          );
        }

        try {
          final activities = await StravaClientManager()
              .stravaClient
              .activities
              .listLoggedInAthleteActivities(
                now,
                startTime,
                currentPage,
                perPage,
              );

          if (activities.isEmpty) {
            Logger.d('没有更多活动数据，同步完成', tag: 'ActivityService');
            hasMoreActivities = false;
            break;
          }

          Logger.d('从 Strava API 获取到第 $currentPage 页的 ${activities.length} 个活动',
              tag: 'ActivityService');

          // 遍历活动，检查是否需要保存
          int newActivityCount = 0;
          for (var activity in activities) {
            if (latestDbActivityId == null || activity.id! > latestDbActivityId) {
              try {
                await saveActivity(activity);
                successCount++;
                newActivityCount++;
                if (onProgress != null) {
                  onProgress(
                    (currentPage - 1) * perPage.toDouble() + activities.indexOf(activity),
                    currentPage * perPage.toDouble(),
                    '正在保存新活动数据 ($successCount)...',
                  );
                }
              } catch (e) {
                Logger.e('保存活动 ${activity.id} 失败: $e', tag: 'ActivityService');
                errorCount++;
              }
            } else {
              Logger.d('活动 ${activity.id} 已存在', tag: 'ActivityService');
            }
          }

          // 如果当前页没有新活动，记录日志但继续获取下一页，直到API返回空数据
          if (newActivityCount == 0) {
            Logger.d('当前页面没有新活动，继续检查下一页', tag: 'ActivityService');
          }

          currentPage++;
          
          // 每同步完一页，更新一次同步状态
          await updateSyncStatus(
            lastPage: 0, // 修改为0，确保每次同步从第一页开始
            totalActivities: await _getActivityCount(db),
          );

        } catch (e) {
          Logger.e('获取第 $currentPage 页活动数据失败: $e', tag: 'ActivityService');
          hasMoreActivities = false;
          break;
        }
      }

      // 最终更新同步状态
      final totalActivities = await _getActivityCount(db);
      await updateSyncStatus(
        lastPage: 0, // 修改为0，确保每次同步从第一页开始
        totalActivities: totalActivities,
      );

      stopwatch.stop();
      Logger.d(
          '同步完成 - 成功: $successCount, 失败: $errorCount, 总页数: ${currentPage - 1}, 总活动数: $totalActivities, 耗时: ${stopwatch.elapsed.inSeconds}秒',
          tag: 'ActivityService');

      if (onProgress != null) {
        onProgress(
          successCount.toDouble(),
          successCount.toDouble(),
          '同步完成，共同步 $successCount 个新活动，数据库共有 $totalActivities 个活动',
        );
      }
    } catch (e) {
      Logger.e('同步活动数据失败: $e', tag: 'ActivityService');
      rethrow;
    }
  }

  /// 获取活动总数
  Future<int> _getActivityCount(Database db) async {
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 插入或更新活动数据
  Future<void> _insertOrUpdateActivity(
      Database db, SummaryActivity activity) async {
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
        'created_at': DateTime.now().toLocal().toIso8601String(),
        'updated_at': DateTime.now().toLocal().toIso8601String(),
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

  /// 根据日期获取活动列表
  Future<List<Map<String, dynamic>>> getActivitiesByDate(DateTime date) async {
    try {
      final db = await database;
      
      // 确保使用本地日期
      final localDate = date.toLocal();
      
      // 格式化日期为YYYY-MM-DD格式，使用本地时区
      final dateStr = "${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}";
      
      // 在查询中匹配本地日期的前缀部分
      final result = await db.rawQuery(
        'SELECT * FROM $tableName WHERE start_date_local LIKE ? ORDER BY start_date_local DESC',
        ['$dateStr%']
      );
      
      return result;
    } catch (e) {
      Logger.e('按日期获取活动数据失败: $e', tag: 'ActivityService');
      return [];
    }
  }

  /// 获取指定月份的活动统计数据
  /// 返回：包含不同类型活动的距离、爬升、卡路里等统计信息
  Future<Map<String, dynamic>> getMonthlyStats(int year, int month) async {
    try {
      final db = await database;

      // 构建月份查询条件（格式：'YYYY-MM-%'）
      final monthStr = month.toString().padLeft(2, '0');
      final datePrefix = '$year-$monthStr';

      // 查询该月所有活动，使用本地时间
      final activities = await db.query(
        tableName,
        where: "start_date_local LIKE ?",
        whereArgs: ['$datePrefix%'],
      );

      // 初始化统计结果
      final stats = {
        'totalActivities': activities.length,
        'totalDistance': 0.0, // 总距离 (米)
        'totalElevationGain': 0.0, // 总爬升 (米)
        'totalKilojoules': 0.0, // 总卡路里消耗 (千焦)
        'totalMovingTime': 0, // 总运动时间 (秒)

        // 按活动类型分类的统计
        'byActivityType': <String, Map<String, dynamic>>{},

        // 记录每天是否有活动
        'activeDays': <int>{},
      };

      // 遍历活动并累加数据
      for (final activity in activities) {
        // 累加总计数据
        stats['totalDistance'] = (stats['totalDistance'] as double) +
            (activity['distance'] as double? ?? 0.0);
        stats['totalElevationGain'] = (stats['totalElevationGain'] as double) +
            (activity['total_elevation_gain'] as double? ?? 0.0);
        stats['totalKilojoules'] = (stats['totalKilojoules'] as double) +
            (activity['kilojoules'] as double? ?? 0.0);
        stats['totalMovingTime'] = (stats['totalMovingTime'] as int) +
            (activity['moving_time'] as int? ?? 0);

        // 提取活动日期并记录活跃日（使用本地时间）
        final startDate = DateTime.parse(activity['start_date_local'] as String);
        (stats['activeDays'] as Set<int>).add(startDate.day);

        // 按活动类型分类统计
        final activityType = activity['type'] as String? ?? '未知';
        final typeStats = (stats['byActivityType']
                as Map<String, Map<String, dynamic>>)[activityType] ??
            {
              'count': 0,
              'distance': 0.0,
              'elevationGain': 0.0,
              'kilojoules': 0.0,
              'movingTime': 0,
            };

        typeStats['count'] = (typeStats['count'] as int) + 1;
        typeStats['distance'] = (typeStats['distance'] as double) +
            (activity['distance'] as double? ?? 0.0);
        typeStats['elevationGain'] = (typeStats['elevationGain'] as double) +
            (activity['total_elevation_gain'] as double? ?? 0.0);
        typeStats['kilojoules'] = (typeStats['kilojoules'] as double) +
            (activity['kilojoules'] as double? ?? 0.0);
        typeStats['movingTime'] = (typeStats['movingTime'] as int) +
            (activity['moving_time'] as int? ?? 0);

        (stats['byActivityType']
            as Map<String, Map<String, dynamic>>)[activityType] = typeStats;
      }

      // 计算活跃天数
      stats['activeDaysCount'] = (stats['activeDays'] as Set<int>).length;

      // 转换Set为List以便JSON序列化
      stats['activeDays'] = (stats['activeDays'] as Set<int>).toList()..sort();

      return stats;
    } catch (e) {
      Logger.e('获取月度统计数据失败: $e', tag: 'ActivityService');
      return {
        'totalActivities': 0,
        'totalDistance': 0.0,
        'totalElevationGain': 0.0,
        'totalKilojoules': 0.0,
        'totalMovingTime': 0,
        'byActivityType': {},
        'activeDays': [],
        'activeDaysCount': 0,
        'error': e.toString(),
      };
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
      Logger.d('查询结果: ${results.isNotEmpty ? '找到活动' : '未找到活动'}',
          tag: 'ActivityService');
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
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'");

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
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$syncTableName'");
    return tables.isNotEmpty;
  }

  /// 获取所有活动的SVG缓存状态
  Future<Map<String, bool>> getSvgCache() async {
    final Map<String, bool> svgCache = {};
    try {
      // 获取数据库中所有活动的起始日期（使用本地时间）
      final db = await database;
      final List<Map<String, dynamic>> activities = await db.query(
        tableName,
        columns: ['start_date_local'],
        where: 'start_date_local IS NOT NULL',
      );

      Logger.d('正在为 ${activities.length} 个活动生成SVG缓存', tag: 'ActivityService');

      // 对于每个活动，检查对应日期的SVG文件是否存在
      for (var activity in activities) {
        if (activity['start_date_local'] != null) {
          try {
            final startDate = DateTime.parse(activity['start_date_local']).toLocal();
            final dateStr = CalendarUtils.formatDateToString(startDate);
            svgCache[dateStr] = await CalendarUtils.doesSvgExist(dateStr);
          } catch (e) {
            Logger.e('处理活动日期出错: ${activity['start_date_local']}',
                error: e, tag: 'ActivityService');
          }
        }
      }

      // 获取当前月和前后各两个月的SVG状态，确保日历显示完整
      final now = DateTime.now().toLocal();
      for (int i = -2; i <= 2; i++) {
        final month = DateTime(now.year, now.month + i).toLocal();
        final monthCache = await CalendarUtils.preloadSvgForMonth(month);
        svgCache.addAll(monthCache);
      }

      Logger.d('SVG缓存生成完成，共 ${svgCache.length} 项', tag: 'ActivityService');
      return svgCache;
    } catch (e) {
      Logger.e('生成SVG缓存出错', error: e, tag: 'ActivityService');
      return {};
    }
  }

  /// 保存活动数据
  Future<void> saveActivity(SummaryActivity activity) async {
    try {
      // 确保所有日期是本地时间
      final startDate = activity.startDate != null 
          ? DateTime.parse(activity.startDate!).toLocal().toIso8601String()
          : null;
      final startDateLocal = activity.startDateLocal != null 
          ? DateTime.parse(activity.startDateLocal!).toLocal().toIso8601String()
          : null;
          
      // 创建一个新的活动对象，包含本地化后的日期
      final updatedActivity = SummaryActivity(
        id: activity.id,
        resourceState: activity.resourceState,
        name: activity.name,
        distance: activity.distance,
        movingTime: activity.movingTime,
        elapsedTime: activity.elapsedTime,
        totalElevationGain: activity.totalElevationGain,
        type: activity.type,
        workoutType: activity.workoutType,
        externalId: activity.externalId,
        uploadId: activity.uploadId,
        startDate: startDate,
        startDateLocal: startDateLocal,
        timezone: activity.timezone,
        utcOffset: activity.utcOffset,
        startLatlng: activity.startLatlng,
        endLatlng: activity.endLatlng,
        locationCity: activity.locationCity,
        locationState: activity.locationState,
        locationCountry: activity.locationCountry,
        achievementCount: activity.achievementCount,
        kudosCount: activity.kudosCount,
        commentCount: activity.commentCount,
        athleteCount: activity.athleteCount,
        photoCount: activity.photoCount,
        map: activity.map,
        trainer: activity.trainer,
        commute: activity.commute,
        manual: activity.manual,
        private: activity.private,
        flagged: activity.flagged,
        gearId: activity.gearId,
        fromAcceptedTag: activity.fromAcceptedTag,
        averageSpeed: activity.averageSpeed,
        maxSpeed: activity.maxSpeed,
        averageCadence: activity.averageCadence,
        averageWatts: activity.averageWatts,
        weightedAverageWatts: activity.weightedAverageWatts,
        kilojoules: activity.kilojoules,
        deviceWatts: activity.deviceWatts,
        hasHeartrate: activity.hasHeartrate,
        averageHeartrate: activity.averageHeartrate,
        maxHeartrate: activity.maxHeartrate,
        maxWatts: activity.maxWatts,
        prCount: activity.prCount,
        totalPhotoCount: activity.totalPhotoCount,
        hasKudoed: activity.hasKudoed,
        sufferScore: activity.sufferScore,
        athlete: activity.athlete,
      );
      
      final db = await database;
      await _insertOrUpdateActivity(db, updatedActivity);
    } catch (e) {
      Logger.e('保存活动失败: $e', tag: 'ActivityService');
      rethrow;
    }
  }

  /// 获取所有活动的总距离（公里）
  Future<double> getTotalDistance() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT SUM(distance) as total_distance FROM $tableName');
      
      // rawQuery返回的是Map列表，我们取第一个元素的total_distance字段
      final totalDistanceInMeters = result.first['total_distance'] as double? ?? 0.0;
      
      // 转换为公里并返回，保留一位小数
      final totalDistanceInKm = (totalDistanceInMeters / 1000.0);
      
      Logger.d('获取总距离: ${totalDistanceInKm.toStringAsFixed(1)} 公里', tag: 'ActivityService');
      return totalDistanceInKm;
    } catch (e) {
      Logger.e('获取总距离失败: $e', tag: 'ActivityService');
      return 0.0;
    }
  }

  /// 获取所有活动的总爬升（米）
  Future<double> getTotalElevation() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT SUM(total_elevation_gain) as total_elevation FROM $tableName');
      
      final totalElevation = result.first['total_elevation'] as double? ?? 0.0;
      
      Logger.d('获取总爬升: ${totalElevation.toStringAsFixed(0)} 米', tag: 'ActivityService');
      return totalElevation;
    } catch (e) {
      Logger.e('获取总爬升失败: $e', tag: 'ActivityService');
      return 0.0;
    }
  }
  
  /// 获取所有活动的总能量（千焦）
  Future<double> getTotalKilojoules() async {
    try {
      final db = await database;
      // 修改查询语句，确保包含所有活动类型的能量数据
      final result = await db.rawQuery('''
        SELECT SUM(
          CASE 
            WHEN type = 'Ride' AND kilojoules > 0 THEN kilojoules
            WHEN type = 'VirtualRide' AND kilojoules > 0 THEN kilojoules
            WHEN type = 'Run' AND moving_time > 0 THEN moving_time * 0.9 * 4.184
            WHEN type = 'VirtualRun' AND moving_time > 0 THEN moving_time * 0.9 * 4.184
            WHEN type = 'Walk' AND moving_time > 0 THEN moving_time * 0.5 * 4.184
            WHEN type = 'Hike' AND moving_time > 0 THEN moving_time * 0.7 * 4.184
            WHEN type = 'Swim' AND moving_time > 0 THEN moving_time * 0.8 * 4.184
            WHEN moving_time > 0 THEN moving_time * 0.6 * 4.184
            ELSE 0 
          END
        ) as total_kilojoules 
        FROM $tableName
      ''');
      
      final totalKilojoules = result.first['total_kilojoules'] as double? ?? 0.0;
      
      Logger.d('获取总能量: ${totalKilojoules.toStringAsFixed(0)} kJ', tag: 'ActivityService');
      return totalKilojoules;
    } catch (e) {
      Logger.e('获取总能量失败: $e', tag: 'ActivityService');
      return 0.0;
    }
  }
  
  /// 获取按活动类型分组的统计数据
  Future<Map<String, Map<String, dynamic>>> getStatsByActivityType() async {
    try {
      final db = await database;
      final activities = await db.query(tableName);
      
      final Map<String, Map<String, dynamic>> statsByType = {};
      
      for (final activity in activities) {
        final type = activity['type'] as String? ?? '未知';
        
        if (!statsByType.containsKey(type)) {
          statsByType[type] = {
            'count': 0,
            'distance': 0.0,
            'total_elevation_gain': 0.0,
            'kilojoules': 0.0,
            'moving_time': 0,
          };
        }
        
        statsByType[type]!['count'] = (statsByType[type]!['count'] as int) + 1;
        statsByType[type]!['distance'] = (statsByType[type]!['distance'] as double) + (activity['distance'] as double? ?? 0.0);
        statsByType[type]!['total_elevation_gain'] = (statsByType[type]!['total_elevation_gain'] as double) + (activity['total_elevation_gain'] as double? ?? 0.0);
        statsByType[type]!['kilojoules'] = (statsByType[type]!['kilojoules'] as double) + (activity['kilojoules'] as double? ?? 0.0);
        statsByType[type]!['moving_time'] = (statsByType[type]!['moving_time'] as int) + (activity['moving_time'] as int? ?? 0);
      }
      
      // 将米转换为公里
      for (final type in statsByType.keys) {
        statsByType[type]!['distance'] = (statsByType[type]!['distance'] as double) / 1000.0;
      }
      
      Logger.d('获取按活动类型分组的统计数据: ${statsByType.length} 种类型', tag: 'ActivityService');
      return statsByType;
    } catch (e) {
      Logger.e('获取按活动类型分组的统计数据失败: $e', tag: 'ActivityService');
      return {};
    }
  }
}
