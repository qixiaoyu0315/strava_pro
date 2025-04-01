import 'package:strava_client/strava_client.dart';
import 'strava_client_manager.dart';

/// 路线服务类，处理路线数据相关操作
class RouteService {
  /// 获取运动员信息
  /// 返回运动员详细信息
  Future<DetailedAthlete> getAthleteInfo() async {
    return await StravaClientManager().stravaClient.athletes.getAuthenticatedAthlete();
  }
  
  /// 获取运动员路线列表
  /// 转换为App内部使用的路线数据格式
  Future<List<Map<String, dynamic>>> getRoutes() async {
    List<Map<String, dynamic>> routeList = [];
    
    try {
      final routes = await StravaClientManager()
          .stravaClient
          .routes
          .listAthleteRoutes(115603263, 1, 10);
          
      for (var route in routes) {
        routeList.add(_convertRouteToMap(route));
      }
    } catch (e) {
      rethrow; // 将异常向上传递，让调用者处理
    }
    
    return routeList;
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