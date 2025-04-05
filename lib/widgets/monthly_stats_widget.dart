import 'package:flutter/material.dart';
import '../service/activity_service.dart';
import 'package:intl/intl.dart';

/// 显示月度活动统计信息的Widget
class MonthlyStatsWidget extends StatefulWidget {
  final DateTime month;
  final ActivityService activityService;
  final bool showCard;

  const MonthlyStatsWidget({
    super.key,
    required this.month,
    required this.activityService,
    this.showCard = true,
  });

  @override
  State<MonthlyStatsWidget> createState() => _MonthlyStatsWidgetState();
}

class _MonthlyStatsWidgetState extends State<MonthlyStatsWidget> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  bool _canceled = false;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  @override
  void dispose() {
    _canceled = true; // 标记组件已被销毁
    super.dispose();
  }
  
  @override
  void didUpdateWidget(MonthlyStatsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当月份更改时重新加载数据
    if (oldWidget.month.year != widget.month.year || 
        oldWidget.month.month != widget.month.month) {
      _loadStats();
    }
  }
  
  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    
    // 使用一个本地变量存储取消状态，以便在异步操作中捕获当前状态
    final cancelToken = _canceled;
    
    final stats = await widget.activityService.getMonthlyStats(
      widget.month.year, 
      widget.month.month
    );
    
    // 如果组件已被销毁或标记为取消，则不更新状态
    if (cancelToken || !mounted) return;
    
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 获取当前主题的颜色
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_stats['totalActivities'] == 0) {
      return widget.showCard 
          ? Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    '本月没有活动记录',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '本月没有活动记录',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            );
    }
    
    // 格式化数字
    final distanceFormat = NumberFormat("#,##0.00");
    final elevationFormat = NumberFormat("#,##0");
    final kilojouleFormat = NumberFormat("#,##0");
    final timeFormat = NumberFormat("0");
    
    // 计算时间的小时和分钟
    final totalMovingTimeMinutes = (_stats['totalMovingTime'] as int) ~/ 60;
    
    // 活动类型分类计数
    Map<String, Map<String, dynamic>> activityTypes = 
        Map<String, Map<String, dynamic>>.from(_stats['byActivityType'] as Map);
    
    final content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('yyyy年MM月').format(widget.month)}活动统计',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // 总体统计行
          Row(
            children: [
              _buildStatItem(
                context,
                '总活动',
                '${_stats['totalActivities']}次',
                Icons.directions_run,
              ),
              _buildStatItem(
                context,
                '活动天数',
                '${_stats['activeDaysCount']}天',
                Icons.calendar_today,
              ),
              _buildStatItem(
                context,
                '总时间',
                '$totalMovingTimeMinutes分钟',
                Icons.access_time,
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 运动数据统计行
          Row(
            children: [
              _buildStatItem(
                context,
                '总距离',
                '${distanceFormat.format(_stats['totalDistance'] / 1000)}公里',
                Icons.straighten,
              ),
              _buildStatItem(
                context,
                '总爬升',
                '${elevationFormat.format(_stats['totalElevationGain'])}米',
                Icons.terrain,
              ),
              _buildStatItem(
                context,
                '活动时间',
                '$totalMovingTimeMinutes分钟',
                Icons.access_time,
              ),
            ],
          ),
          
          // 活动类型细节
          if (activityTypes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '活动类型明细',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            // 每个活动类型的明细
            for (var entry in activityTypes.entries)
              _buildActivityTypeRow(context, entry.key, entry.value),
          ],
        ],
      ),
    );
    
    return widget.showCard 
        ? Card(
            margin: const EdgeInsets.all(8.0),
            child: content,
          )
        : content;
  }
  
  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActivityTypeRow(BuildContext context, String type, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    
    // 根据活动类型选择图标
    IconData typeIcon;
    Color typeColor;
    
    switch (type) {
      case 'Run':
        typeIcon = Icons.directions_run;
        typeColor = Colors.orange;
        break;
      case 'Ride':
        typeIcon = Icons.directions_bike;
        typeColor = Colors.blue;
        break;
      case 'Swim':
        typeIcon = Icons.pool;
        typeColor = Colors.lightBlue;
        break;
      case 'Walk':
        typeIcon = Icons.directions_walk;
        typeColor = Colors.green;
        break;
      case 'Hike':
        typeIcon = Icons.terrain;
        typeColor = Colors.brown;
        break;
      default:
        typeIcon = Icons.fitness_center;
        typeColor = Colors.grey;
    }
    
    // 格式化数据
    final distance = (data['distance'] as double) / 1000; // 转换为公里
    final elevationGain = data['elevationGain'] as double;
    final kilojoules = data['kilojoules'] as double;
    final count = data['count'] as int;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(typeIcon, color: typeColor, size: 20),
          const SizedBox(width: 8),
          Text(
            _translateActivityType(type),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            ' ($count次)',
            style: TextStyle(
              color: theme.textTheme.bodySmall?.color,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            '${NumberFormat("#,##0.0").format(distance)}公里',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Text(
            '爬升${NumberFormat("#,##0").format(elevationGain)}米',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
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
} 