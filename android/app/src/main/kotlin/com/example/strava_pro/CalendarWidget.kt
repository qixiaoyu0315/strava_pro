package com.example.strava_pro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.io.File
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.util.Log
import android.widget.Toast
import android.graphics.drawable.Icon
import java.io.FileInputStream
import android.net.Uri

class CalendarWidget : AppWidgetProvider() {
    
    companion object {
        private const val ACTION_PREV_MONTH = "com.example.strava_pro.ACTION_PREV_MONTH"
        private const val ACTION_NEXT_MONTH = "com.example.strava_pro.ACTION_NEXT_MONTH"
        private const val ACTION_SELECT_DATE = "com.example.strava_pro.ACTION_SELECT_DATE"
        private const val ACTION_VIEW_PNG = "com.example.strava_pro.ACTION_VIEW_PNG"
        private const val PREF_MONTH_KEY = "calendar_widget_month"
        private const val PREF_YEAR_KEY = "calendar_widget_year"
        private const val PREF_SELECTED_DAY_KEY = "calendar_widget_selected_day"
        private const val TAG = "CalendarWidget"
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
                
                // 获取日期字符串
                val dateStr = "${year}-${(month + 1).toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"
                
                // 检查是否有对应的PNG图片
                val pngPath = "/storage/emulated/0/Download/strava_pro/png/$dateStr.png"
                val pngExists = File(pngPath).exists()
                
                if (pngExists) {
                    // 如果有PNG图片，打开图片查看器
                    try {
                        val viewIntent = Intent(Intent.ACTION_VIEW)
                        val photoUri = Uri.fromFile(File(pngPath))
                        viewIntent.setDataAndType(photoUri, "image/png")
                        viewIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(viewIntent)
                        return
                    } catch (e: Exception) {
                        Log.e(TAG, "Error opening PNG image", e)
                        // 如果打开图片失败，继续执行下面的代码
                    }
                }
                
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
            ACTION_VIEW_PNG -> {
                val pngPath = intent.getStringExtra("png_path") ?: return
                try {
                    val viewIntent = Intent(Intent.ACTION_VIEW)
                    val photoUri = Uri.fromFile(File(pngPath))
                    viewIntent.setDataAndType(photoUri, "image/png")
                    viewIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(viewIntent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error opening PNG image", e)
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
        
        // 内存管理 - 计算最大可用于PNG图像的内存量
        val maxMemoryForAllImages = 12_000_000 // 小于Android的限制15,552,000字节
        var usedMemory = 0
        val maxImagesPerWidget = 15 // 增加允许显示的图片数量
        var loadedImagesCount = 0
        
        // 首先扫描该月有多少天有PNG图片，以便合理分配内存
        val daysWithPng = mutableListOf<Int>()
        for (day in 1..daysInMonth) {
            val dateStr = "${displayYear}-${(displayMonth + 1).toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"
            val pngPath = "/storage/emulated/0/Download/strava_pro/png/$dateStr.png"
            if (File(pngPath).exists()) {
                daysWithPng.add(day)
            }
        }
        
        Log.d(TAG, "Found ${daysWithPng.size} days with PNG images")
        
        // 如果一个月中的PNG图片数量超过了最大允许数量，则均匀选择要显示的日期
        val daysToShow = if (daysWithPng.size > maxImagesPerWidget) {
            // 计算选择间隔，确保均匀分布
            val interval = daysWithPng.size / maxImagesPerWidget
            val selectedDays = mutableListOf<Int>()
            
            // 选择均匀分布的日期，优先显示最后几天的图片(更新的活动)
            if (interval > 1) {
                for (i in daysWithPng.size - 1 downTo 0 step interval) {
                    if (selectedDays.size < maxImagesPerWidget) {
                        selectedDays.add(daysWithPng[i])
                    }
                }
            } else {
                // 如果间隔小于1，则取前maxImagesPerWidget个
                selectedDays.addAll(daysWithPng.takeLast(maxImagesPerWidget))
            }
            
            selectedDays.sorted() // 确保按日期顺序排列
        } else {
            // 如果PNG图片数量不超过最大允许数量，则显示所有图片
            daysWithPng
        }
        
        Log.d(TAG, "Will show PNG images for these days: $daysToShow")
        
        // 填充日期，采用高效的内存管理
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
            
            // 判断是否有PNG图片（活动数据）
            val dateStr = "${displayYear}-${(displayMonth + 1).toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"
            val pngPath = "/storage/emulated/0/Download/strava_pro/png/$dateStr.png"
            val pngExists = File(pngPath).exists()
            
            // 设置日期颜色和背景样式
            if (pngExists && day in daysToShow && loadedImagesCount < maxImagesPerWidget && usedMemory < maxMemoryForAllImages) {
                try {
                    // 创建一个新的日期单元格视图，包含ImageView和TextView
                    val cellView = RemoteViews(context.packageName, R.layout.calendar_day_cell)
                    
                    // 设置日期文本
                    cellView.setTextViewText(R.id.day_text, day.toString())
                    
                    // 根据周几设置文本颜色
                    when (dayOfWeek) {
                        Calendar.SATURDAY -> cellView.setTextColor(R.id.day_text, Color.rgb(64, 149, 255))
                        Calendar.SUNDAY -> cellView.setTextColor(R.id.day_text, Color.rgb(255, 64, 64))
                        else -> cellView.setTextColor(R.id.day_text, Color.WHITE)
                    }
                    
                    // 如果是当天或选中的日期，设置文本背景
                    if (isSelected) {
                        cellView.setInt(R.id.day_text, "setBackgroundResource", R.drawable.selected_background)
                    } else if (isToday) {
                        cellView.setInt(R.id.day_text, "setBackgroundResource", R.drawable.today_background)
                    }
                    
                    // 设置图片
                    val file = File(pngPath)
                    if (file.exists()) {
                        try {
                            // 加载PNG图片，严格控制内存使用
                            val options = BitmapFactory.Options().apply {
                                // 先仅解码尺寸信息
                                inJustDecodeBounds = true
                            }
                            BitmapFactory.decodeFile(pngPath, options)
                            
                            // 计算合适的缩放比例，确保图片大小适应日历单元格
                            val targetSize = 96 // 目标大小，减小以节省内存
                            
                            // 计算缩放系数
                            val widthScale = options.outWidth / targetSize
                            val heightScale = options.outHeight / targetSize
                            var sampleSize = 1
                            
                            // 不断增加采样率直到适合目标大小
                            while (widthScale / sampleSize > 2 || heightScale / sampleSize > 2) {
                                sampleSize *= 2
                            }
                            
                            // 确保采样不要太大，以便图片清晰可见
                            sampleSize = sampleSize.coerceAtMost(8)
                            
                            Log.d(TAG, "Day $day image: original size ${options.outWidth}x${options.outHeight}, sample size: $sampleSize")
                            
                            // 使用新的配置加载图片
                            options.inJustDecodeBounds = false
                            options.inSampleSize = sampleSize
                            options.inPreferredConfig = Bitmap.Config.RGB_565 // 使用16位位图节省内存
                            
                            val bitmap = BitmapFactory.decodeFile(pngPath, options)
                            if (bitmap != null) {
                                val imageMemory = bitmap.byteCount
                                
                                // 只检查内存是否超出总限制
                                if (usedMemory + imageMemory <= maxMemoryForAllImages) {
                                    try {
                                        // 确保日期文本位于图片上方且清晰可见
                                        cellView.setInt(R.id.day_text, "setTextColor", Color.WHITE)
                                        
                                        // 设置图片到ImageView
                                        cellView.setImageViewBitmap(R.id.day_image, bitmap)
                                        cellView.setViewVisibility(R.id.day_image, View.VISIBLE)
                                        
                                        // 更新内存使用计数
                                        usedMemory += imageMemory
                                        loadedImagesCount++
                                        
                                        Log.d(TAG, "Loaded PNG for day $day: size=${bitmap.width}x${bitmap.height}, memory=${bitmap.byteCount} bytes, total=$usedMemory")
                                        
                                        // 将整个日期单元格视图添加到布局中
                                        views.removeAllViews(dayId)
                                        views.addView(dayId, cellView)
                                        
                                        // 设置点击事件
                                        val selectIntent = Intent(context, CalendarWidget::class.java).apply {
                                            action = ACTION_SELECT_DATE
                                            putExtra("day", day)
                                            putExtra("month", displayMonth)
                                            putExtra("year", displayYear)
                                        }
                                        
                                        val pendingIntent = PendingIntent.getBroadcast(
                                            context,
                                            day * 100 + displayMonth * 10 + (displayYear % 10),
                                            selectIntent,
                                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                        )
                                        
                                        views.setOnClickPendingIntent(dayId, pendingIntent)
                                        continue // 跳过后面的默认样式设置
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error setting image to view for day $day", e)
                                        bitmap.recycle() // 出错时释放内存
                                    }
                                } else {
                                    Log.w(TAG, "Skipping PNG for day $day due to memory limit: would use ${bitmap.byteCount}, limit=$maxMemoryForAllImages, current=$usedMemory")
                                    bitmap.recycle() // 立即释放内存
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error loading PNG image for day $day", e)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error creating cell view for day $day", e)
                }
            }
            
            // 如果没有加载PNG图片或者加载失败，则使用普通样式
            if (isSelected) {
                // 选中日期用蓝色背景，白色文字
                views.setTextColor(dayId, Color.WHITE)
                views.setInt(dayId, "setBackgroundResource", R.drawable.selected_background)
                views.setTextViewText(dayId, day.toString())
            } else if (isToday) {
                // 当天日期用绿色背景，白色文字
                views.setTextColor(dayId, Color.WHITE)
                views.setInt(dayId, "setBackgroundResource", R.drawable.today_background)
                views.setTextViewText(dayId, day.toString())
            } else if (pngExists) {
                // 对于有PNG但未加载的日期，使用紫色背景标记
                views.setTextColor(dayId, Color.WHITE)
                views.setInt(dayId, "setBackgroundColor", Color.rgb(128, 0, 128))  // 紫色
                views.setTextViewText(dayId, day.toString())
            } else {
                // 其他日期使用默认样式
                defaultStyle(views, dayId, day, dayOfWeek)
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
                    day * 100 + displayMonth * 10 + (displayYear % 10),
                    selectIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
        
        Log.d(TAG, "Widget update complete. Total memory used: $usedMemory bytes for $loadedImagesCount images")
        
        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // 设置默认日期样式
    private fun defaultStyle(views: RemoteViews, dayId: Int, day: Int, dayOfWeek: Int) {
        views.setTextViewText(dayId, day.toString())
        
        when (dayOfWeek) {
            Calendar.SATURDAY -> {
                // 周六显示蓝色
                views.setTextColor(dayId, Color.rgb(64, 149, 255))
                views.setInt(dayId, "setBackgroundResource", 0)
            }
            Calendar.SUNDAY -> {
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
    }

    // 创建一个带有突出显示背景色的Bitmap
    private fun createHighlightedBitmap(original: Bitmap, backgroundColor: Int): Bitmap {
        // 创建一个新的Bitmap，与原始图像相同大小
        val resultBitmap = Bitmap.createBitmap(original.width, original.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(resultBitmap)
        
        // 先绘制背景色
        canvas.drawColor(backgroundColor)
        
        // 在背景上绘制原始图像
        canvas.drawBitmap(original, 0f, 0f, null)
        
        return resultBitmap
    }
} 