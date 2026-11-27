package com.fortunefusion.fortune

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    // [소원방 v2.6 배경화면] docs/WALLPAPER.md §4 "7. Flutter 연결" —
    // MainActivity.configureFlutterEngine → WallpaperPlugin(this).register(engine).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WallpaperPlugin(this).register(flutterEngine)
    }
}

