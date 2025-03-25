import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart' show rootBundle;

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;
  final Map<String, bool> _svgCache = {}; // 缓存 SVG 存在状态

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _preloadSvgForMonth(_displayedMonth);
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
    _preloadSvgForMonth(_displayedMonth);
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
    _preloadSvgForMonth(_displayedMonth);
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: 300,
            height: 400,
            child: YearMonthPicker(
              initialDate: _displayedMonth,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != _displayedMonth) {
      setState(() {
        _displayedMonth = picked;
      });
      _preloadSvgForMonth(_displayedMonth);
    }
  }

  List<DateTime?> _getDaysInMonth() {
    final List<DateTime?> days = List.filled(42, null);
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;

    for (int i = 0; i < daysInMonth; i++) {
      days[firstWeekday - 1 + i] = DateTime(_displayedMonth.year, _displayedMonth.month, i + 1);
    }

    return days;
  }

  Future<void> _preloadSvgForMonth(DateTime month) async {
    final List<DateTime?> days = _getDaysInMonth();
    for (final day in days) {
      if (day == null) continue;
      String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
      String svgPath = 'assets/$formattedDate';

      _svgCache[svgPath] = await _doesSvgExist(svgPath);
    }
    setState(() {});
  }

  Future<bool> _doesSvgExist(String assetPath) async {
    if (_svgCache.containsKey(assetPath)) {
      return _svgCache[assetPath]!;
    }
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _selectMonth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_displayedMonth.year}年${_displayedMonth.month}月',
                style: const TextStyle(fontSize: 20),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (DragEndDetails details) {
          if (details.primaryVelocity! > 0) {
            // 向右滑动，显示上一个月
            _previousMonth();
          } else if (details.primaryVelocity! < 0) {
            // 向左滑动，显示下一个月
            _nextMonth();
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Text('一'),
                  Text('二'),
                  Text('三'),
                  Text('四'),
                  Text('五'),
                  Text('六'),
                  Text('日'),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(), // 禁用网格滚动，以便支持整体滑动
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.7,
                ),
                itemCount: 42,
                itemBuilder: (context, index) {
                  final days = _getDaysInMonth();
                  final day = days[index];
                  final isToday = day?.year == DateTime.now().year &&
                      day?.month == DateTime.now().month &&
                      day?.day == DateTime.now().day;
                  final isSelected = day?.year == _selectedDate.year &&
                      day?.month == _selectedDate.month &&
                      day?.day == _selectedDate.day;

                  if (day == null) {
                    return const SizedBox();
                  }

                  String formattedDate = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}.svg';
                  String svgPath = 'assets/$formattedDate';

                  String assetToLoad = (_svgCache.containsKey(svgPath) && _svgCache[svgPath]!)
                      ? svgPath
                      : 'assets/calendar_icon.svg';

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = day;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue
                            : isToday
                                ? Colors.blue.withOpacity(0.3)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : null,
                                fontWeight: isToday ? FontWeight.bold : null,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SvgPicture.asset(
                                  assetToLoad,
                                  colorFilter: ColorFilter.mode(
                                    isSelected ? Colors.white : Colors.green,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class YearMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const YearMonthPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<YearMonthPicker> createState() => _YearMonthPickerState();
}

class _YearMonthPickerState extends State<YearMonthPicker> {
  late int _selectedYear;
  late int _selectedMonth;
  late PageController _yearController;
  late PageController _monthController;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _yearController = PageController(
      initialPage: _selectedYear - widget.firstDate.year,
      viewportFraction: 0.3,
    );
    _monthController = PageController(
      initialPage: _selectedMonth - 1,
      viewportFraction: 0.3,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const Text('选择年份', style: TextStyle(fontSize: 16)),
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _yearController,
            onPageChanged: (int index) {
              setState(() {
                _selectedYear = widget.firstDate.year + index;
              });
            },
            itemCount: widget.lastDate.year - widget.firstDate.year + 1,
            itemBuilder: (context, index) {
              final year = widget.firstDate.year + index;
              return Center(
                child: Text(
                  '$year年',
                  style: TextStyle(
                    fontSize: year == _selectedYear ? 24 : 16,
                    fontWeight: year == _selectedYear ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const Text('选择月份', style: TextStyle(fontSize: 16)),
        SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _monthController,
            onPageChanged: (int index) {
              setState(() {
                _selectedMonth = index + 1;
              });
            },
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              return Center(
                child: Text(
                  '$month月',
                  style: TextStyle(
                    fontSize: month == _selectedMonth ? 24 : 16,
                    fontWeight: month == _selectedMonth ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  DateTime(_selectedYear, _selectedMonth),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }
}
