package com.eyesonlyapp.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val systemChannel = "com.eyesonlyapp.app/system"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"openSecuritySettings" -> {
						startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}
}
