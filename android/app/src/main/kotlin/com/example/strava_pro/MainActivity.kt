package com.example.strava_pro

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.os.Bundle
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.strava_pro/calendar_widget"
    
    // 保存选择的日期
    private var selectedDay = -1
    private var selectedMonth = -1
    private var selectedYear = -1
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 设置方法通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSelectedDate" -> {
                    val dateMap = HashMap<String, Int>()
                    dateMap["day"] = selectedDay
                    dateMap["month"] = selectedMonth
                    dateMap["year"] = selectedYear
                    result.success(dateMap)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
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
        val day = intent.getIntExtra("selected_day", -1)
        val month = intent.getIntExtra("selected_month", -1)
        val year = intent.getIntExtra("selected_year", -1)
        
        // 如果有选择的日期，则保存起来
        if (day != -1 && month != -1 && year != -1) {
            selectedDay = day
            selectedMonth = month
            selectedYear = year
        }
    }
}
