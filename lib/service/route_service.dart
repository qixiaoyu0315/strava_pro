import 'package:strava_client/strava_client.dart';
import 'strava_client_manager.dart';
import '../model/athlete_model.dart';

/// 路线服务类，处理路线数据相关操作
class RouteService {
  final AthleteModel _athleteModel = AthleteModel();
  
  /// 获取运动员信息
  /// 返回运动员详细信息
  Future<DetailedAthlete> getAthleteInfo() async {
    return await StravaClientManager().stravaClient.athletes.getAuthenticatedAthlete();
  }
  
  /// 获取运动员路线列表
  /// 转换为App内部使用的路线数据格式
  /// [page] 页码，从1开始
  /// [perPage] 每页显示数量，默认20
  Future<List<Map<String, dynamic>>> getRoutes({int page = 1, int perPage = 20}) async {
    List<Map<String, dynamic>> routeList = [];
    
    try {
      // 从数据库获取运动员ID
      final athleteData = await _athleteModel.getAthlete();
      if (athleteData == null || !athleteData.containsKey('id')) {
        // 如果数据库中没有运动员数据，则尝试获取当前认证的运动员信息
        final athlete = await getAthleteInfo();
        // 保存到数据库中
        await _athleteModel.saveAthlete(athlete);
        // 使用获取到的ID
        final routes = await StravaClientManager()
            .stravaClient
            .routes
            .listAthleteRoutes(athlete.id, page, perPage);
            
        for (var route in routes) {
          routeList.add(_convertRouteToMap(route));
        }
      } else {
        // 使用数据库中存储的运动员ID
        final athleteId = athleteData['id'] as int;
        final routes = await StravaClientManager()
            .stravaClient
            .routes
            .listAthleteRoutes(athleteId, page, perPage);
            
        for (var route in routes) {
          routeList.add(_convertRouteToMap(route));
        }
      }
    } catch (e) {
      rethrow; // 将异常向上传递，让调用者处理
    }
    
    return routeList;
  }
  
  /// 获取路线总数（用于分页）
  Future<int> getRoutesCount() async {
    try {
      // 从数据库获取运动员ID
      final athleteData = await _athleteModel.getAthlete();
      int athleteId;
      
      if (athleteData == null || !athleteData.containsKey('id')) {
        // 如果数据库中没有运动员数据，则尝试获取当前认证的运动员信息
        final athlete = await getAthleteInfo();
        athleteId = athlete.id;
      } else {
        athleteId = athleteData['id'] as int;
      }
      
      // 尝试获取一页50个路线来估计总数
      final routes = await StravaClientManager()
          .stravaClient
          .routes
          .listAthleteRoutes(athleteId, 1, 50);
          
      return routes.length;
    } catch (e) {
      return 0; // 出错时返回0
    }
  }
  
  /// 将路线对象转换为Map格式
  Map<String, dynamic> _convertRouteToMap(dynamic route) {
    return {
      'idStr': route.idStr ?? '未知',
      'name': route.name ?? '未知',
      'mapUrl': route.mapUrls?.url ?? '无地图链接',
      'mapDarkUrl': route.mapUrls?.darkUrl ?? route.mapUrls?.url ?? '无地图链接',
      'distance': (route.distance ?? 0) / 1000, // 转换为公里
      'elevationGain': route.elevationGain ?? 0, // 高度
      'estimatedMovingTime': (route.estimatedMovingTime ?? 0) / 3600, // 转换为小时
    };
  }
  
  /// 获取路线详情 - 注意：实际API方法可能需要根据Strava API调整
  Future<Map<String, dynamic>?> getRouteDetails(String routeId) async {
    try {
      // 此处使用适当的API方法获取路线详情
      // Strava API需要整数ID，因此尝试转换字符串ID
      int? id = int.tryParse(routeId);
      if (id == null) {
        throw ArgumentError('无效的路线ID: $routeId');
      }
      
      final route = await StravaClientManager()
          .stravaClient
          .routes
          .getRoute(id);
      
      return _convertRouteToMap(route);
    } catch (e) {
      rethrow;
    }
  }
} 