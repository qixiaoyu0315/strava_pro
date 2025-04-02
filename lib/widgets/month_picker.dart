import 'package:flutter/material.dart';

class MonthPicker extends StatefulWidget {
  final DateTime initialMonth;
  final Function(DateTime) onMonthSelected;
  
  const MonthPicker({
    super.key,
    required this.initialMonth,
    required this.onMonthSelected,
  });

  @override
  State<MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<MonthPicker> {
  late int _selectedYear;
  late int _selectedMonth;
  
  final List<String> _months = [
    "1月", "2月", "3月", "4月", "5月", "6月", 
    "7月", "8月", "9月", "10月", "11月", "12月"
  ];
  
  final int _startYear = DateTime.now().year - 2;
  final int _endYear = DateTime.now().year + 2;
  
  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialMonth.year;
    _selectedMonth = widget.initialMonth.month;
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择月份'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 年份选择器
            DropdownButton<int>(
              isExpanded: true,
              value: _selectedYear,
              items: List<DropdownMenuItem<int>>.generate(
                _endYear - _startYear + 1,
                (index) => DropdownMenuItem<int>(
                  value: _startYear + index,
                  child: Text('${_startYear + index}年'),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedYear = value;
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            
            // 月份网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = month == _selectedMonth;
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMonth = month;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(
                        _months[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onMonthSelected(DateTime(_selectedYear, _selectedMonth));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
