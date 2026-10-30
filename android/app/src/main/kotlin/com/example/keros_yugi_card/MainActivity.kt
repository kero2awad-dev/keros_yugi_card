package com.example.keros_yugi_card

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // منع التقاط سكرين شوت أو تسجيل الشاشة
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
