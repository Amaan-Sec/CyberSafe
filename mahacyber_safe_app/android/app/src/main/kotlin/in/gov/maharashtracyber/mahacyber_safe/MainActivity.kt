package `in`.gov.maharashtracyber.mahacyber_safe

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "in.gov.maharashtracyber.mahacyber_safe/share_intent"
    }

    private var shareChannel: MethodChannel? = null
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceInsightChannel(applicationContext, flutterEngine)

        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        shareChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitial" -> {
                    val text = extractSharedText(intent) ?: pendingSharedText
                    pendingSharedText = null
                    result.success(text)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val text = extractSharedText(intent)
        if (text != null) {
            // Forward to Dart if engine is ready; otherwise hold for getInitial().
            shareChannel?.invokeMethod("onShared", text) ?: run { pendingSharedText = text }
        }
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type != "text/plain") return null
        return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
    }
}
