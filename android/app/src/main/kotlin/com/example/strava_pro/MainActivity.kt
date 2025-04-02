package com.example.strava_pro

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.strava_pro/calendar_widget"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 处理从小组件启动的Intent
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // 处理新的Intent
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        // 从Intent中获取选择的日期
        val selectedDay = intent.getIntExtra("selected_day", -1)
        val selectedMonth = intent.getIntExtra("selected_month", -1)
        val selectedYear = intent.getIntExtra("selected_year", -1)
        
        // 如果有选择的日期，则传递给Flutter
        if (selectedDay != -1 && selectedMonth != -1 && selectedYear != -1) {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                    if (call.method == "getSelectedDate") {
                        val dateMap = HashMap<String, Int>()
                        dateMap["day"] = selectedDay
                        dateMap["month"] = selectedMonth
                        dateMap["year"] = selectedYear
                        result.success(dateMap)
                    } else {
                        result.notImplemented()
                    }
                }
            }
        }
    }
}
