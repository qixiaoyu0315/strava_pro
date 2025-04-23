import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../page/activity_detail_page.dart';

class ActivityListDialog extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> activities;

  const ActivityListDialog({
    super.key,
    required this.date,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    // 格式化日期显示
    final DateFormat dateFormat = DateFormat('yyyy年MM月dd日 (E)');
    final String formattedDate = dateFormat.format(date);

    return AlertDialog(
      title: Text('$formattedDate的活动'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            
            // 格式化距离（从米转为千米）
            final double distance = (activity['distance'] as double?) ?? 0.0;
            final String formattedDistance = 
                '${(distance / 1000).toStringAsFixed(1)}公里';
            
            // 格式化时间（从秒转为小时:分钟）
            final int movingTime = (activity['moving_time'] as int?) ?? 0;
            final int hours = movingTime ~/ 3600;
            final int minutes = (movingTime % 3600) ~/ 60;
            final String formattedTime = 
                '${hours > 0 ? '$hours小时' : ''}${minutes}分钟';
            
            // 爬升
            final double elevationGain = 
                (activity['total_elevation_gain'] as double?) ?? 0.0;
            final String formattedElevation = 
                '${elevationGain.toInt()}米';
            
            // 活动类型
            final String activityType = activity['type'] ?? '未知';
            final String typeChinese = _translateActivityType(activityType);
            
            // 活动图标
            IconData activityIcon = _getActivityIcon(activityType);
            
            // 活动颜色
            Color activityColor = _getActivityColor(activityType);
            
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: activityColor.withOpacity(0.1),
                  child: Icon(activityIcon, color: activityColor),
                ),
                title: Text(
                  activity['name'] ?? '未命名活动',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$typeChinese · $formattedDistance · $formattedTime'),
                    if (elevationGain > 0)
                      Text('爬升: $formattedElevation'),
                  ],
                ),
                isThreeLine: elevationGain > 0,
                onTap: () {
                  // 关闭弹窗
                  Navigator.of(context).pop();
                  
                  // 跳转到活动详情页
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ActivityDetailPage(
                      activityId: activity['activity_id'].toString(),
                    ),
                  ));
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
  
  // 将活动类型转换为中文
  String _translateActivityType(String type) {
    switch (type) {
      case 'Run':
        return '跑步';
      case 'Ride':
        return '骑行';
      case 'Swim':
        return '游泳';
      case 'Walk':
        return '步行';
      case 'Hike':
        return '徒步';
      case 'Workout':
        return '锻炼';
      case 'WeightTraining':
        return '力量训练';
      case 'Yoga':
        return '瑜伽';
      case 'VirtualRide':
        return '虚拟骑行';
      case 'VirtualRun':
        return '虚拟跑步';
      default:
        return type;
    }
  }
  
  // 根据活动类型获取图标
  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Run':
        return Icons.directions_run;
      case 'Ride':
        return Icons.directions_bike;
      case 'Swim':
        return Icons.pool;
      case 'Walk':
        return Icons.directions_walk;
      case 'Hike':
        return Icons.terrain;
      case 'Workout':
        return Icons.fitness_center;
      case 'WeightTraining':
        return Icons.fitness_center;
      case 'Yoga':
        return Icons.self_improvement;
      case 'VirtualRide':
        return Icons.computer;
      case 'VirtualRun':
        return Icons.computer;
      default:
        return Icons.directions_run;
    }
  }
  
  // 根据活动类型获取颜色
  Color _getActivityColor(String type) {
    switch (type) {
      case 'Run':
        return Colors.orange;
      case 'Ride':
        return Colors.blue;
      case 'Swim':
        return Colors.lightBlue;
      case 'Walk':
        return Colors.green;
      case 'Hike':
        return Colors.brown;
      case 'Workout':
        return Colors.deepPurple;
      case 'WeightTraining':
        return Colors.indigo;
      case 'Yoga':
        return Colors.teal;
      case 'VirtualRide':
        return Colors.cyan;
      case 'VirtualRun':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
} 