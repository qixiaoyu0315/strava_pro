package com.example.strava_pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.view.WindowManager
import android.provider.Settings
import android.os.PowerManager
import android.content.Context
import android.util.Log

class MainActivity: FlutterActivity() {
    private val REFRESH_RATE_CHANNEL = "com.example.strava_pro/refresh_rate"
    private val DEVICE_STATUS_CHANNEL = "com.example.strava_pro/device_status"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 设置刷新率通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REFRESH_RATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRefreshRate" -> {
                        result.success(getDeviceRefreshRate())
                    }
                    "setHighRefreshRate" -> {
                        setHighRefreshRate()
                        result.success(null)
                    }
                    "setStandardRefreshRate" -> {
                        setStandardRefreshRate()
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
            
        // 设置设备状态通道
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_STATUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBatteryLevel" -> {
                        result.success(getBatteryLevel())
                    }
                    "isCharging" -> {
                        result.success(isDeviceCharging())
                    }
                    "isPowerSaveMode" -> {
                        result.success(isPowerSaveMode())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
    
    // 获取设备刷新率
    private fun getDeviceRefreshRate(): Float {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val display = display
                display?.refreshRate ?: 60f
            } catch (e: Exception) {
                Log.e(TAG, "获取设备刷新率失败", e)
                60f
            }
        } else {
            try {
                window.windowManager.defaultDisplay.refreshRate
            } catch (e: Exception) {
                Log.e(TAG, "获取设备刷新率失败", e)
                60f
            }
        }
    }
    
    // 设置高刷新率
    private fun setHighRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.attributes.preferredRefreshRate = getMaxRefreshRate()
                window.attributes.preferredDisplayModeId = 0
                window.setAttributes(window.attributes)
                Log.d(TAG, "已设置高刷新率模式: ${getMaxRefreshRate()}")
            } else {
                val layoutParams = window.attributes
                layoutParams.preferredRefreshRate = getMaxRefreshRate()
                window.attributes = layoutParams
                Log.d(TAG, "已设置高刷新率模式: ${getMaxRefreshRate()}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "设置高刷新率失败", e)
        }
    }
    
    // 设置标准刷新率 (60Hz)
    private fun setStandardRefreshRate() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.attributes.preferredRefreshRate = 60f
                window.attributes.preferredDisplayModeId = 0
                window.setAttributes(window.attributes)
                Log.d(TAG, "已设置标准刷新率模式: 60Hz")
            } else {
                val layoutParams = window.attributes
                layoutParams.preferredRefreshRate = 60f
                window.attributes = layoutParams
                Log.d(TAG, "已设置标准刷新率模式: 60Hz")
            }
        } catch (e: Exception) {
            Log.e(TAG, "设置标准刷新率失败", e)
        }
    }
    
    // 获取设备最大刷新率
    private fun getMaxRefreshRate(): Float {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                var maxRate = 60f
                display?.supportedModes?.forEach { mode ->
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                    }
                }
                maxRate
            } catch (e: Exception) {
                Log.e(TAG, "获取设备最大刷新率失败", e)
                60f
            }
        } else {
            try {
                var maxRate = 60f
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    window.windowManager.defaultDisplay.supportedModes.forEach { mode ->
                        if (mode.refreshRate > maxRate) {
                            maxRate = mode.refreshRate
                        }
                    }
                } else {
                    maxRate = window.windowManager.defaultDisplay.refreshRate
                }
                maxRate
            } catch (e: Exception) {
                Log.e(TAG, "获取设备最大刷新率失败", e)
                60f
            }
        }
    }
    
    // 获取电池电量
    private fun getBatteryLevel(): Int {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                return batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
            }
        } catch (e: Exception) {
            Log.e(TAG, "获取电池电量失败", e)
        }
        return 100 // 默认返回100%
    }
    
    // 检查设备是否正在充电
    private fun isDeviceCharging(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                return batteryManager.isCharging
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查设备充电状态失败", e)
        }
        return false
    }
    
    // 检查是否处于省电模式
    private fun isPowerSaveMode(): Boolean {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                return powerManager.isPowerSaveMode
            }
        } catch (e: Exception) {
            Log.e(TAG, "检查省电模式状态失败", e)
        }
        return false
    }
}
