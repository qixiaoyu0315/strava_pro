package com.example.strava_pro;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.widget.RemoteViews;
import android.graphics.Color;
import java.util.Calendar;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class CalendarWidget extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.calendar_widget);
        
        // 获取当前日期
        Calendar calendar = Calendar.getInstance();
        
        // 设置月份标题
        SimpleDateFormat monthFormat = new SimpleDateFormat("M月", Locale.CHINESE);
        String monthText = monthFormat.format(calendar.getTime());
        views.setTextViewText(R.id.month_text, monthText);

        // 获取当月第一天是星期几和当月天数
        int currentDay = calendar.get(Calendar.DAY_OF_MONTH);
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

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views);
    }
} 