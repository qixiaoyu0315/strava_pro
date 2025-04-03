package com.example.strava_pro

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.graphics.BitmapFactory
import android.util.Log
import android.app.PendingIntent
import android.os.Build
import android.content.res.Configuration
import java.io.File
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * 日历小组件接收器
 * 用于处理小组件的更新和交互
 */
class CalendarWidgetReceiver : AppWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "Widget onUpdate called")
        
        // 遍历所有小组件实例
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            WIDGET_CLICK -> {
                // 处理小组件点击事件
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID
                )
                
                Log.d(TAG, "Widget clicked: $appWidgetId")
                
                // 启动主应用
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(launchIntent)
                }
            }
            Intent.ACTION_CONFIGURATION_CHANGED -> {
                // 监听系统配置变更（包括主题变化）
                Log.d(TAG, "系统配置变更，可能包含主题变化")
                
                // 获取当前实例的所有小组件ID
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisAppWidget = android.content.ComponentName(
                    context.packageName,
                    this.javaClass.name
                )
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
                
                // 如果有小组件实例存在，则更新它们
                if (appWidgetIds.isNotEmpty()) {
                    Log.d(TAG, "找到 ${appWidgetIds.size} 个小组件实例，正在更新")
                    onUpdate(context, appWidgetManager, appWidgetIds)
                } else {
                    Log.d(TAG, "未找到小组件实例")
                }
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // 系统启动完成或应用更新后
                Log.d(TAG, "系统启动完成或应用已更新，正在初始化小组件")
                
                // 获取当前实例的所有小组件ID
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisAppWidget = android.content.ComponentName(
                    context.packageName,
                    this.javaClass.name
                )
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
                
                // 如果有小组件实例存在，则更新它们
                if (appWidgetIds.isNotEmpty()) {
                    Log.d(TAG, "找到 ${appWidgetIds.size} 个小组件实例，正在更新")
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
        }
    }

    // 当小组件第一次添加到桌面时调用
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "小组件已启用")
    }

    // 当最后一个小组件实例从桌面移除时调用
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "小组件已禁用")
    }
    
    companion object {
        const val TAG = "CalendarWidget"
        const val WIDGET_CLICK = "com.example.strava_pro.CALENDAR_WIDGET_CLICK"
        const val IMAGE_PATH_KEY = "calendar_image_path"
        const val DEFAULT_IMAGE_PATH = "/storage/emulated/0/Download/strava_pro/month/2025_01_calendar.png"
    }
}

/**
 * 更新小组件视图
 */
private fun updateAppWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    Log.d("CalendarWidget", "Updating widget $appWidgetId")
    
    // 获取小组件视图
    val views = RemoteViews(context.packageName, R.layout.calendar_widget_layout)
    
    // 检测系统当前主题模式（日间/夜间）
    val isDarkMode = when (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) {
        Configuration.UI_MODE_NIGHT_YES -> true
        else -> false
    }
    
    // 根据主题设置背景
    if (isDarkMode) {
        Log.d("CalendarWidget", "使用夜间模式背景")
        views.setInt(R.id.widget_root_layout, "setBackgroundResource", R.color.widget_background_dark)
    } else {
        Log.d("CalendarWidget", "使用日间模式背景")
        views.setInt(R.id.widget_root_layout, "setBackgroundResource", R.color.widget_background_light)
    }
    
    // 获取存储的图片路径
    val widgetData = HomeWidgetPlugin.getData(context)
    val imagePath = widgetData.getString(
        CalendarWidgetReceiver.IMAGE_PATH_KEY, 
        CalendarWidgetReceiver.DEFAULT_IMAGE_PATH
    )
    
    try {
        // 检查文件是否存在
        val imageFile = File(imagePath)
        if (imageFile.exists()) {
            // 从文件加载图片并设置到小组件
            val bitmap = BitmapFactory.decodeFile(imagePath)
            views.setImageViewBitmap(R.id.widget_calendar_image, bitmap)
            views.setViewVisibility(R.id.widget_error_text, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_calendar_image, android.view.View.VISIBLE)
            Log.d("CalendarWidget", "设置图片成功: $imagePath")
        } else {
            Log.e("CalendarWidget", "图片文件不存在: $imagePath")
            // 如果文件不存在，可以设置默认图片或显示错误信息
            views.setTextViewText(R.id.widget_error_text, "日历图片未找到")
            views.setViewVisibility(R.id.widget_error_text, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_calendar_image, android.view.View.GONE)
        }
        
        // 创建点击事件
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        
        val clickIntent = Intent(context, CalendarWidgetReceiver::class.java).apply {
            action = CalendarWidgetReceiver.WIDGET_CLICK
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("appwidget://$appWidgetId")
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            appWidgetId,
            clickIntent,
            pendingIntentFlags
        )
        
        // 设置点击事件
        views.setOnClickPendingIntent(R.id.widget_root_layout, pendingIntent)
        
        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
        
    } catch (e: Exception) {
        Log.e("CalendarWidget", "更新小组件失败: ${e.message}", e)
        // 显示错误信息
        views.setTextViewText(R.id.widget_error_text, "加载失败: ${e.message}")
        views.setViewVisibility(R.id.widget_error_text, android.view.View.VISIBLE)
        views.setViewVisibility(R.id.widget_calendar_image, android.view.View.GONE)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
} 