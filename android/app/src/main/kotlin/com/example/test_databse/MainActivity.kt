package com.example.test_databse

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.google.android.gms.maps.MapsInitializer // 1. Import
import com.google.android.gms.maps.MapsInitializer.Renderer // 2. Import

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {

        // 3. เพิ่ม 3 บรรทัดนี้เข้าไป
        MapsInitializer.initialize(applicationContext, Renderer.LEGACY) { renderer ->
            // คุณสามารถดู log ตรงนี้ได้ว่าใช้ Renderer ตัวไหน
        }

        super.configureFlutterEngine(flutterEngine)
    }
}