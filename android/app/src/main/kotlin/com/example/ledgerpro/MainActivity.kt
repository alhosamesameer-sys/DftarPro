package com.example.ledgerpro

import android.content.Intent
import android.net.Uri
import java.net.URLEncoder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "dftar/whatsapp"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method != "openWhatsApp") { result.notImplemented(); return@setMethodCallHandler }
            val phone = call.argument<String>("phone") ?: ""
            val text = call.argument<String>("text") ?: ""
            val business = call.argument<Boolean>("business") ?: false
            if (phone.isBlank()) { result.success(false); return@setMethodCallHandler }
            try {
                val pkg = if (business) "com.whatsapp.w4b" else "com.whatsapp"
                val url = "https://wa.me/$phone?text=${URLEncoder.encode(text, "UTF-8")}"
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply { setPackage(pkg) }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent); result.success(true)
                } else result.success(false)
            } catch (_: Exception) { result.success(false) }
        }
    }
}
