import 'package:flutter/material.dart';

class MonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onMonthSelected;

  const MonthPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onMonthSelected,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    return showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: SizedBox(
            width: 300,
            height: 400,
            child: MonthPicker(
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              onMonthSelected: (date) {
                Navigator.of(context).pop(date);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  _MonthPickerState createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
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
      initialPage: widget.initialDate.year - widget.firstDate.year,
      viewportFraction: 0.3,
    );
    _monthController = PageController(
      initialPage: widget.initialDate.month - 1,
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
                  '$year',
                  style: TextStyle(
                    fontSize: year == _selectedYear ? 24 : 16,
                    fontWeight: year == _selectedYear
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                    fontWeight: month == _selectedMonth
                        ? FontWeight.bold
                        : FontWeight.normal,
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
                widget.onMonthSelected(DateTime(_selectedYear, _selectedMonth));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ],
    );
  }
}
