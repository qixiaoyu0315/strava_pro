import 'package:strava_client/strava_client.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'strava_client_manager.dart';
import '../utils/logger.dart';

/// 活动服务类，处理活动数据的同步和存储
class ActivityService {
  static Database? _database;
  static const String tableName = 'activities';
  
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
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        Logger.d('创建活动数据表', tag: 'ActivityService');
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
        Logger.d('活动数据表创建完成', tag: 'ActivityService');
      },
    );
  }
  
  /// 同步活动数据
  Future<void> syncActivities() async {
    try {
      Logger.d('开始同步活动数据', tag: 'ActivityService');
      
      // 使用当前时间作为结束时间
      final now = DateTime.now().toUtc();
      // 获取30天前的活动
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      Logger.d('获取活动数据，从 ${thirtyDaysAgo.toIso8601String()} 到 ${now.toIso8601String()}', 
          tag: 'ActivityService');
      
      // 获取活动列表
      final activities = await StravaClientManager()
          .stravaClient
          .activities
          .listLoggedInAthleteActivities(
            now,
            thirtyDaysAgo,
            1,
            100,
          );
      
      if (activities.isEmpty) {
        Logger.d('未获取到任何活动数据', tag: 'ActivityService');
        return;
      }
      
      Logger.d('从 Strava API 获取到 ${activities.length} 个活动', tag: 'ActivityService');
          
      final db = await database;
      int successCount = 0;
      int errorCount = 0;
      
      for (var activity in activities) {
        try {
          // 获取详细活动信息
          Logger.d('获取活动 ${activity.id} 的详细信息', tag: 'ActivityService');
          final detailedActivity = await StravaClientManager()
              .stravaClient
              .activities
              .getActivity(activity.id!);
              
          await _insertOrUpdateActivity(db, detailedActivity);
          successCount++;
          Logger.d('成功保存活动 ${activity.id} 到数据库', tag: 'ActivityService');
        } catch (e) {
          errorCount++;
          Logger.e('处理活动 ${activity.id} 时出错: ${e.toString()}', error: e, tag: 'ActivityService');
        }
      }
      
      // 验证同步结果
      final count = await db.query(tableName);
      Logger.d('同步完成，成功: $successCount, 失败: $errorCount, 数据库中现有 ${count.length} 个活动', 
          tag: 'ActivityService');
          
      if (errorCount > 0) {
        throw Exception('同步过程中有 $errorCount 个活动处理失败');
      }
    } catch (e, stackTrace) {
      Logger.e('同步活动数据失败: ${e.toString()}', error: e, stackTrace: stackTrace, tag: 'ActivityService');
      rethrow;
    }
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
} 