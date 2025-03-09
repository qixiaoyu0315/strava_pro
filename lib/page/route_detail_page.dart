import 'package:flutter/material.dart';
import '../service/strava_client_manager.dart';
import 'package:strava_client/strava_client.dart' as strava;

class RouteDetailPage extends StatelessWidget {
  final String idStr;

  const RouteDetailPage({Key? key, required this.idStr}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Details'),
      ),
      body: FutureBuilder<strava.Route>(
        future: getRoute(idStr),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('获取路线失败: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('没有找到路线'));
          }

          final routeData = snapshot.data!;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('路线名称: ${routeData.name}', style: TextStyle(fontSize: 24)),
                Text('距离: ${routeData.distance} km', style: TextStyle(fontSize: 18)),
                Text('累计爬升: ${routeData.elevationGain} m', style: TextStyle(fontSize: 18)),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<strava.Route> getRoute(String idStr) async {
  int routeId = int.parse(idStr);
  return await StravaClientManager().stravaClient.routes.getRoute(routeId);
} 