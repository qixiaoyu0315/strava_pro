package com.example.strava_pro;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;
import android.graphics.Color;
import java.util.Calendar;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class CalendarWidget extends AppWidgetProvider {
    // 常量定义
    private static final String PREFS_NAME = "com.example.strava_pro.CalendarWidget";
    private static final String PREF_PREFIX_KEY = "widget_";
    private static final String ACTION_PREV_MONTH = "com.example.strava_pro.ACTION_PREV_MONTH";
    private static final String ACTION_NEXT_MONTH = "com.example.strava_pro.ACTION_NEXT_MONTH";
    private static final String EXTRA_WIDGET_ID = "widget_id";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        
        // 处理按钮点击事件
        AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
        
        if (ACTION_PREV_MONTH.equals(intent.getAction()) || ACTION_NEXT_MONTH.equals(intent.getAction())) {
            int widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                // 获取存储的年月
                Calendar calendar = getStoredCalendar(context, widgetId);
                
                // 上一个月或下一个月
                if (ACTION_PREV_MONTH.equals(intent.getAction())) {
                    calendar.add(Calendar.MONTH, -1);
                } else {
                    calendar.add(Calendar.MONTH, 1);
                }
                
                // 保存更新后的年月
                saveCalendar(context, widgetId, calendar);
                
                // 更新小组件
                updateAppWidget(context, appWidgetManager, widgetId);
            }
        }
    }

    private void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.calendar_widget);
        
        // 获取存储的日期或使用当前日期
        Calendar calendar = getStoredCalendar(context, appWidgetId);
        
        // 设置月份标题
        SimpleDateFormat monthFormat = new SimpleDateFormat("yyyy年M月", Locale.CHINESE);
        String monthText = monthFormat.format(calendar.getTime());
        views.setTextViewText(R.id.month_text, monthText);

        // 获取当前日期（用于高亮显示）
        Calendar today = Calendar.getInstance();
        boolean isCurrentMonth = (today.get(Calendar.YEAR) == calendar.get(Calendar.YEAR) && 
                                today.get(Calendar.MONTH) == calendar.get(Calendar.MONTH));
        int currentDay = isCurrentMonth ? today.get(Calendar.DAY_OF_MONTH) : -1;
        
        // 获取当月第一天是星期几和当月天数
        int dayOfMonth = calendar.get(Calendar.DAY_OF_MONTH);
        calendar.set(Calendar.DAY_OF_MONTH, 1);
        int firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1;
        int daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH);

        // 清空所有日期格子
        for (int i = 1; i <= 42; i++) {
            int viewId = context.getResources().getIdentifier("day_" + i, "id", context.getPackageName());
            views.setTextViewText(viewId, "");
            views.setTextColor(viewId, Color.WHITE);
        }

        // 填充当月日期
        for (int i = 1; i <= daysInMonth; i++) {
            int position = firstDayOfWeek + i;
            int viewId = context.getResources().getIdentifier("day_" + position, "id", context.getPackageName());
            views.setTextViewText(viewId, String.valueOf(i));
            
            if (i == currentDay) {
                views.setTextColor(viewId, Color.RED);
            }
        }

        // 设置按钮点击事件
        setPendingIntentButtons(context, views, appWidgetId);

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }
    
    // 设置按钮的点击事件处理
    private void setPendingIntentButtons(Context context, RemoteViews views, int appWidgetId) {
        // 上个月按钮
        Intent intentPrev = new Intent(context, CalendarWidget.class);
        intentPrev.setAction(ACTION_PREV_MONTH);
        intentPrev.putExtra(EXTRA_WIDGET_ID, appWidgetId);
        PendingIntent pendingIntentPrev = PendingIntent.getBroadcast(context, appWidgetId*10, intentPrev, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.prev_month_button, pendingIntentPrev);
        
        // 下个月按钮
        Intent intentNext = new Intent(context, CalendarWidget.class);
        intentNext.setAction(ACTION_NEXT_MONTH);
        intentNext.putExtra(EXTRA_WIDGET_ID, appWidgetId);
        PendingIntent pendingIntentNext = PendingIntent.getBroadcast(context, appWidgetId*10+1, intentNext, 
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.next_month_button, pendingIntentNext);
    }
    
    // 获取存储的日历对象
    private Calendar getStoredCalendar(Context context, int appWidgetId) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, 0);
        String prefKey = PREF_PREFIX_KEY + appWidgetId;
        long timeInMillis = prefs.getLong(prefKey, System.currentTimeMillis());
        
        Calendar calendar = Calendar.getInstance();
        calendar.setTimeInMillis(timeInMillis);
        
        return calendar;
    }
    
    // 保存日历对象
    private void saveCalendar(Context context, int appWidgetId, Calendar calendar) {
        SharedPreferences.Editor prefs = context.getSharedPreferences(PREFS_NAME, 0).edit();
        String prefKey = PREF_PREFIX_KEY + appWidgetId;
        prefs.putLong(prefKey, calendar.getTimeInMillis());
        prefs.apply();
    }
    
    @Override
    public void onDeleted(Context context, int[] appWidgetIds) {
        // 当小组件被删除时，清除存储的偏好设置
        SharedPreferences.Editor prefs = context.getSharedPreferences(PREFS_NAME, 0).edit();
        for (int appWidgetId : appWidgetIds) {
            prefs.remove(PREF_PREFIX_KEY + appWidgetId);
        }
        prefs.apply();
        super.onDeleted(context, appWidgetIds);
    }
} 