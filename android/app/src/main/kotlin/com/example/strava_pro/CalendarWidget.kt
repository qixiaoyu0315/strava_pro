package com.example.strava_pro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.io.File

class CalendarWidget : AppWidgetProvider() {
    
    companion object {
        private const val ACTION_PREV_MONTH = "com.example.strava_pro.ACTION_PREV_MONTH"
        private const val ACTION_NEXT_MONTH = "com.example.strava_pro.ACTION_NEXT_MONTH"
        private const val ACTION_SELECT_DATE = "com.example.strava_pro.ACTION_SELECT_DATE"
        private const val PREF_MONTH_KEY = "calendar_widget_month"
        private const val PREF_YEAR_KEY = "calendar_widget_year"
        private const val PREF_SELECTED_DAY_KEY = "calendar_widget_selected_day"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 为每个小组件实例执行更新
        for (appWidgetId in appWidgetIds) {
            updateCalendarWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(intent.component)
        
        when (intent.action) {
            ACTION_PREV_MONTH -> {
                val prefs = context.getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
                var month = prefs.getInt(PREF_MONTH_KEY, Calendar.getInstance().get(Calendar.MONTH))
                var year = prefs.getInt(PREF_YEAR_KEY, Calendar.getInstance().get(Calendar.YEAR))
                
                // 前一个月
                month--
                if (month < 0) {
                    month = 11 // 切换到上一年的12月
                    year--
                }
                
                prefs.edit().putInt(PREF_MONTH_KEY, month).putInt(PREF_YEAR_KEY, year).apply()
                
                // 更新所有小组件
                for (appWidgetId in appWidgetIds) {
                    updateCalendarWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_NEXT_MONTH -> {
                val prefs = context.getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
                var month = prefs.getInt(PREF_MONTH_KEY, Calendar.getInstance().get(Calendar.MONTH))
                var year = prefs.getInt(PREF_YEAR_KEY, Calendar.getInstance().get(Calendar.YEAR))
                
                // 下一个月
                month++
                if (month > 11) {
                    month = 0 // 切换到下一年的1月
                    year++
                }
                
                prefs.edit().putInt(PREF_MONTH_KEY, month).putInt(PREF_YEAR_KEY, year).apply()
                
                // 更新所有小组件
                for (appWidgetId in appWidgetIds) {
                    updateCalendarWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_SELECT_DATE -> {
                val day = intent.getIntExtra("day", 1)
                val month = intent.getIntExtra("month", 0)
                val year = intent.getIntExtra("year", 2023)
                
                // 保存选中的日期
                val prefs = context.getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
                prefs.edit().putInt(PREF_SELECTED_DAY_KEY, day).apply()
                
                // 启动主应用并传递选中的日期
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("selected_day", day)
                    launchIntent.putExtra("selected_month", month)
                    launchIntent.putExtra("selected_year", year)
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                }
                
                // 更新所有小组件
                for (appWidgetId in appWidgetIds) {
                    updateCalendarWidget(context, appWidgetManager, appWidgetId)
                }
            }
        }
    }

    private fun updateCalendarWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // 获取保存的年月数据和选中的日期，如果没有则使用当前日期
        val prefs = context.getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
        val currentCalendar = Calendar.getInstance()
        val currentDay = currentCalendar.get(Calendar.DAY_OF_MONTH)
        val currentMonth = currentCalendar.get(Calendar.MONTH)
        val currentYear = currentCalendar.get(Calendar.YEAR)
        
        val displayMonth = prefs.getInt(PREF_MONTH_KEY, currentMonth)
        val displayYear = prefs.getInt(PREF_YEAR_KEY, currentYear)
        val selectedDay = prefs.getInt(PREF_SELECTED_DAY_KEY, currentDay)
        
        // 如果是首次显示，保存当前月份
        if (!prefs.contains(PREF_MONTH_KEY)) {
            prefs.edit()
                .putInt(PREF_MONTH_KEY, currentMonth)
                .putInt(PREF_YEAR_KEY, currentYear)
                .putInt(PREF_SELECTED_DAY_KEY, currentDay)
                .apply()
        }
        
        // 创建RemoteViews
        val views = RemoteViews(context.packageName, R.layout.calendar_widget)
        
        // 设置月份标题
        val monthNames = arrayOf("1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月")
        views.setTextViewText(R.id.month_text, "${displayYear}年${monthNames[displayMonth]}")
        
        // 设置上一个月按钮动作
        val prevIntent = Intent(context, CalendarWidget::class.java).apply {
            action = ACTION_PREV_MONTH
        }
        views.setOnClickPendingIntent(
            R.id.prev_month_button,
            PendingIntent.getBroadcast(
                context,
                0,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        
        // 设置下一个月按钮动作
        val nextIntent = Intent(context, CalendarWidget::class.java).apply {
            action = ACTION_NEXT_MONTH
        }
        views.setOnClickPendingIntent(
            R.id.next_month_button,
            PendingIntent.getBroadcast(
                context,
                1,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        
        // 设置日历网格
        val calendar = Calendar.getInstance().apply {
            set(Calendar.YEAR, displayYear)
            set(Calendar.MONTH, displayMonth)
            set(Calendar.DAY_OF_MONTH, 1)
        }
        
        // 获取这个月的第一天是星期几
        val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1 // 调整为从0开始
        
        // 获取这个月有多少天
        val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
        
        // 清空所有日期
        for (i in 1..42) {
            val dayId = context.resources.getIdentifier("day_$i", "id", context.packageName)
            views.setTextViewText(dayId, "")
            views.setTextColor(dayId, Color.WHITE)
            views.setViewVisibility(dayId, View.INVISIBLE)
            views.setInt(dayId, "setBackgroundResource", 0)
        }
        
        // 填充日期
        for (day in 1..daysInMonth) {
            val position = firstDayOfWeek + day
            val dayId = context.resources.getIdentifier("day_$position", "id", context.packageName)
            views.setViewVisibility(dayId, View.VISIBLE)
            
            // 设置样式（周末，当前日期等）
            calendar.set(Calendar.DAY_OF_MONTH, day)
            val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
            
            // 判断是否是当天
            val isToday = displayYear == currentYear && 
                           displayMonth == currentMonth && 
                           day == currentDay
                           
            // 判断是否是选中的日期
            val isSelected = displayYear == displayYear && 
                             displayMonth == displayMonth && 
                             day == selectedDay &&
                             selectedDay > 0
            
            // 判断是否有SVG图片（活动数据）
            val dateStr = "${displayYear}-${(displayMonth + 1).toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"
            val svgPath = "/storage/emulated/0/Download/strava_pro/svg/$dateStr.svg"
            val svgExists = File(svgPath).exists()
            
            // 设置日期文本
            var dayText = day.toString()
            // 添加笑脸表情符号，如果存在活动
            if (svgExists) {
                dayText = "$day\n😊"
            }
            views.setTextViewText(dayId, dayText)
            
            // 设置日期颜色和背景
            when {
                isSelected -> {
                    // 选中日期用蓝色背景，白色文字
                    views.setTextColor(dayId, Color.WHITE)
                    views.setInt(dayId, "setBackgroundResource", R.drawable.selected_background)
                }
                isToday -> {
                    // 当天日期用蓝色背景，白色文字
                    views.setTextColor(dayId, Color.WHITE)
                    views.setInt(dayId, "setBackgroundResource", R.drawable.today_background)
                }
                dayOfWeek == Calendar.SATURDAY -> {
                    // 周六显示蓝色
                    views.setTextColor(dayId, Color.rgb(64, 149, 255))
                    views.setInt(dayId, "setBackgroundResource", 0)
                }
                dayOfWeek == Calendar.SUNDAY -> {
                    // 周日显示红色
                    views.setTextColor(dayId, Color.rgb(255, 64, 64))
                    views.setInt(dayId, "setBackgroundResource", 0)
                }
                else -> {
                    // 普通日期白色
                    views.setTextColor(dayId, Color.WHITE)
                    views.setInt(dayId, "setBackgroundResource", 0)
                }
            }
            
            // 设置点击事件
            val selectIntent = Intent(context, CalendarWidget::class.java).apply {
                action = ACTION_SELECT_DATE
                putExtra("day", day)
                putExtra("month", displayMonth)
                putExtra("year", displayYear)
            }
            views.setOnClickPendingIntent(
                dayId,
                PendingIntent.getBroadcast(
                    context,
                    day * 100 + displayMonth * 10 + (displayYear % 10), // 生成唯一的请求码
                    selectIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        
        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
} 