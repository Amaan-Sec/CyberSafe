package `in`.gov.maharashtracyber.mahacyber_safe

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.biometric.BiometricManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import android.util.Base64

class DeviceInsightChannel(private val context: Context, engine: FlutterEngine) {
    companion object {
        const val CHANNEL = "mahacyber.safe/device_insight"
    }

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "listInstalledApps" -> result.success(listInstalledApps(call.argument<Boolean>("includeIcons") ?: false))
                    "deviceSecurityChecks" -> result.success(deviceSecurityChecks())
                    "openAppSettings" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) result.error("ARG", "package required", null)
                        else {
                            val i = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg"))
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(i)
                            result.success(true)
                        }
                    }
                    "uninstallApp" -> {
                        val pkg = call.argument<String>("package")
                        if (pkg.isNullOrEmpty()) result.error("ARG", "package required", null)
                        else {
                            val i = Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg"))
                            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(i)
                            result.success(true)
                        }
                    }
                    "openSecuritySettings" -> {
                        val i = Intent(Settings.ACTION_SECURITY_SETTINGS)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(i)
                        result.success(true)
                    }
                    "openDeveloperSettings" -> {
                        val i = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(i)
                        result.success(true)
                    }
                    "listAccessibilityServices" -> result.success(listAccessibilityServices())
                    "getAdwareSignals" -> result.success(getAdwareSignals())
                    "openAccessibilitySettings" -> {
                        val i = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("ERR", t.message, null)
            }
        }
    }

    private fun listInstalledApps(includeIcons: Boolean): List<Map<String, Any?>> {
        val pm = context.packageManager
        val out = ArrayList<Map<String, Any?>>()
        val flags = PackageManager.GET_PERMISSIONS
        val packages = pm.getInstalledPackages(flags)
        for (pkg in packages) {
            val ai = pkg.applicationInfo ?: continue
            val pkgName = pkg.packageName
            val name = pm.getApplicationLabel(ai).toString()
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val hasLauncher = pm.getLaunchIntentForPackage(pkgName) != null
            val installer: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgName)
                }
            } catch (_: Throwable) { null }

            // Permissions: requested + granted
            val requested = pkg.requestedPermissions?.toList() ?: emptyList()
            val flagsArr = pkg.requestedPermissionsFlags
            val granted = ArrayList<String>()
            requested.forEachIndexed { idx, perm ->
                val isGranted = if (flagsArr != null && idx < flagsArr.size) {
                    (flagsArr[idx] and android.content.pm.PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
                } else {
                    pm.checkPermission(perm, pkgName) == PackageManager.PERMISSION_GRANTED
                }
                if (isGranted) granted.add(perm)
            }

            val item = HashMap<String, Any?>()
            item["packageName"] = pkgName
            item["appName"] = name
            item["isSystem"] = isSystem
            item["hasLauncher"] = hasLauncher
            item["installer"] = installer
            item["firstInstall"] = pkg.firstInstallTime
            item["lastUpdate"] = pkg.lastUpdateTime
            item["versionName"] = pkg.versionName ?: ""
            item["targetSdk"] = ai.targetSdkVersion
            item["permissions"] = requested
            item["grantedPermissions"] = granted
            if (includeIcons) {
                item["icon"] = try {
                    drawableToBase64(pm.getApplicationIcon(ai))
                } catch (_: Throwable) { null }
            }
            out.add(item)
        }
        return out
    }

    private fun drawableToBase64(d: Drawable): String {
        val w = if (d.intrinsicWidth > 0) d.intrinsicWidth.coerceAtMost(96) else 64
        val h = if (d.intrinsicHeight > 0) d.intrinsicHeight.coerceAtMost(96) else 64
        val bmp = if (d is BitmapDrawable && d.bitmap != null) {
            Bitmap.createScaledBitmap(d.bitmap, w, h, true)
        } else {
            val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            d.setBounds(0, 0, c.width, c.height)
            d.draw(c)
            b
        }
        val baos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 90, baos)
        return Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
    }

    private fun listAccessibilityServices(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val am = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
        val installed: List<AccessibilityServiceInfo> = am?.getInstalledAccessibilityServiceList() ?: emptyList()

        // Currently-enabled services (raw setting string: "pkg/ServiceName:pkg/ServiceName").
        val enabledRaw = try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
        } catch (_: Throwable) { "" }
        val enabledComponents = enabledRaw.split(":")
            .mapNotNull { ComponentName.unflattenFromString(it) }
            .map { it.packageName + "/" + it.className }
            .toHashSet()
        val enabledPackages = enabledRaw.split(":")
            .mapNotNull { ComponentName.unflattenFromString(it)?.packageName }
            .toHashSet()

        val out = ArrayList<Map<String, Any?>>()
        for (svc in installed) {
            val ri = svc.resolveInfo ?: continue
            val si = ri.serviceInfo ?: continue
            val pkgName = si.packageName ?: continue
            val component = pkgName + "/" + si.name
            val label = try { ri.loadLabel(pm).toString() } catch (_: Throwable) { pkgName }

            val appInfo: ApplicationInfo? = try {
                pm.getApplicationInfo(pkgName, 0)
            } catch (_: Throwable) { null }
            val isSystem = appInfo?.let { (it.flags and ApplicationInfo.FLAG_SYSTEM) != 0 } ?: false
            val installer: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgName)
                }
            } catch (_: Throwable) { null }

            val pkgInfo = try { pm.getPackageInfo(pkgName, 0) } catch (_: Throwable) { null }
            val firstInstall = pkgInfo?.firstInstallTime ?: 0L
            val lastUpdate = pkgInfo?.lastUpdateTime ?: 0L

            val capsMask = svc.capabilities
            val caps = ArrayList<String>()
            if (capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_RETRIEVE_WINDOW_CONTENT != 0) caps.add("retrieve_window_content")
            if (capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_REQUEST_TOUCH_EXPLORATION != 0) caps.add("touch_exploration")
            if (capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_REQUEST_ENHANCED_WEB_ACCESSIBILITY != 0) caps.add("enhanced_web")
            if (capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_REQUEST_FILTER_KEY_EVENTS != 0) caps.add("filter_key_events")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_CONTROL_MAGNIFICATION != 0) caps.add("control_magnification")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                capsMask and AccessibilityServiceInfo.CAPABILITY_CAN_PERFORM_GESTURES != 0) caps.add("perform_gestures")

            val item = HashMap<String, Any?>()
            item["packageName"] = pkgName
            item["component"] = component
            item["serviceLabel"] = label
            item["appName"] = appInfo?.let { pm.getApplicationLabel(it).toString() } ?: label
            item["isSystem"] = isSystem
            item["installer"] = installer
            item["firstInstall"] = firstInstall
            item["lastUpdate"] = lastUpdate
            item["enabled"] = enabledComponents.contains(component) || enabledPackages.contains(pkgName)
            item["capabilities"] = caps
            item["description"] = try { svc.loadDescription(pm) ?: "" } catch (_: Throwable) { "" }
            out.add(item)
        }
        return out
    }

    /**
     * Known ad-network SDK class/package prefixes. We match these against an
     * app's declared activities, services and receivers — when 3+ different
     * networks show up, it's almost always an ad-monetised (often shady) app.
     */
    private val adSdkSignatures: List<Pair<String, String>> = listOf(
        "AdMob (Google)"      to "com.google.android.gms.ads",
        "Google Ads"          to "com.google.ads",
        "AppLovin / MAX"      to "com.applovin",
        "Unity Ads"           to "com.unity3d.ads",
        "Unity Services"      to "com.unity3d.services",
        "Vungle"              to "com.vungle",
        "Mintegral"           to "com.mbridge.msdk",
        "Mintegral (legacy)"  to "com.mintegral",
        "ironSource"          to "com.ironsource",
        "MoPub"               to "com.mopub",
        "Pangle (TikTok)"     to "com.bytedance.sdk.openadsdk",
        "InMobi"              to "com.inmobi",
        "Chartboost"          to "com.chartboost",
        "Tapjoy"              to "com.tapjoy",
        "StartApp"            to "com.startapp",
        "AdColony"            to "com.adcolony",
        "Facebook Audience"   to "com.facebook.ads",
        "Fyber"               to "com.fyber",
        "BidMachine"          to "io.bidmachine",
        "PubMatic"            to "com.pubmatic",
        "Smaato"              to "com.smaato",
        "Yandex Ads"          to "com.yandex.mobile.ads",
        "myTarget"            to "com.my.tracker",
        "AppNext"             to "com.appnext",
        "Kidoz"               to "com.kidoz.sdk",
    )

    private fun getAdwareSignals(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val out = ArrayList<Map<String, Any?>>()
        val flags = PackageManager.GET_PERMISSIONS or
                PackageManager.GET_ACTIVITIES or
                PackageManager.GET_SERVICES or
                PackageManager.GET_RECEIVERS
        val packages = try { pm.getInstalledPackages(flags) } catch (_: Throwable) {
            // Some OEMs throw TransactionTooLarge if the manifest blob is too big;
            // fall back to fewer flags to at least surface partial data.
            pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        }

        for (pkg in packages) {
            val ai = pkg.applicationInfo ?: continue
            val pkgName = pkg.packageName
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            val name = try { pm.getApplicationLabel(ai).toString() } catch (_: Throwable) { pkgName }

            val installer: String? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkgName).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkgName)
                }
            } catch (_: Throwable) { null }

            // Permissions (granted vs only requested)
            val requested = pkg.requestedPermissions?.toList() ?: emptyList()
            val flagsArr = pkg.requestedPermissionsFlags
            val granted = HashSet<String>()
            requested.forEachIndexed { idx, perm ->
                val isGranted = if (flagsArr != null && idx < flagsArr.size) {
                    (flagsArr[idx] and android.content.pm.PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
                } else {
                    pm.checkPermission(perm, pkgName) == PackageManager.PERMISSION_GRANTED
                }
                if (isGranted) granted.add(perm)
            }

            // Scan declared components for ad-SDK signatures
            val componentClasses = HashSet<String>()
            pkg.activities?.forEach { it.name?.let(componentClasses::add) }
            pkg.services?.forEach { it.name?.let(componentClasses::add) }
            pkg.receivers?.forEach { it.name?.let(componentClasses::add) }

            val matchedSdks = LinkedHashSet<String>()
            for ((label, prefix) in adSdkSignatures) {
                if (componentClasses.any { it.startsWith(prefix) }) {
                    matchedSdks.add(label)
                }
            }

            val hasOverlay = granted.contains("android.permission.SYSTEM_ALERT_WINDOW")
            val declaresOverlay = requested.contains("android.permission.SYSTEM_ALERT_WINDOW")
            val declaresAccessibility = requested.contains("android.permission.BIND_ACCESSIBILITY_SERVICE")
            val declaresBootCompleted = requested.contains("android.permission.RECEIVE_BOOT_COMPLETED")
            val declaresWakeLock = requested.contains("android.permission.WAKE_LOCK")
            val declaresInstallPkgs = requested.contains("android.permission.REQUEST_INSTALL_PACKAGES")
            val declaresQueryAll = requested.contains("android.permission.QUERY_ALL_PACKAGES")
            val hasInternet = requested.contains("android.permission.INTERNET")

            val isPlay = installer == "com.android.vending" || installer == "com.google.android.feedback"

            val item = HashMap<String, Any?>()
            item["packageName"] = pkgName
            item["appName"] = name
            item["isSystem"] = isSystem
            item["installer"] = installer
            item["isFromPlayStore"] = isPlay
            item["firstInstall"] = pkg.firstInstallTime
            item["lastUpdate"] = pkg.lastUpdateTime
            item["versionName"] = pkg.versionName ?: ""
            item["adSdkMatches"] = matchedSdks.toList()
            item["adSdkCount"] = matchedSdks.size
            item["hasOverlayGranted"] = hasOverlay
            item["declaresOverlay"] = declaresOverlay
            item["declaresAccessibility"] = declaresAccessibility
            item["declaresBootCompleted"] = declaresBootCompleted
            item["declaresWakeLock"] = declaresWakeLock
            item["declaresInstallPkgs"] = declaresInstallPkgs
            item["declaresQueryAll"] = declaresQueryAll
            item["hasInternet"] = hasInternet
            out.add(item)
        }
        return out
    }

    private fun deviceSecurityChecks(): Map<String, Any?> {
        val m = HashMap<String, Any?>()
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        m["screenLockSet"] = km?.isDeviceSecure ?: false

        // Biometric
        val bm = BiometricManager.from(context)
        val bioStatus = bm.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK)
        m["biometricEnrolled"] = bioStatus == BiometricManager.BIOMETRIC_SUCCESS
        m["biometricAvailable"] = bioStatus != BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE
        m["biometricStatusCode"] = bioStatus

        // Encryption
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        val encStatus = dpm?.storageEncryptionStatus ?: DevicePolicyManager.ENCRYPTION_STATUS_UNSUPPORTED
        m["encryptionStatus"] = encStatus
        m["encryptionEnabled"] = encStatus == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE ||
                encStatus == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVATING ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && encStatus == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER) ||
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q  // Android 10+ encrypts by default

        // OS / patch
        m["androidVersion"] = Build.VERSION.RELEASE
        m["sdkInt"] = Build.VERSION.SDK_INT
        m["manufacturer"] = Build.MANUFACTURER
        m["model"] = Build.MODEL
        m["securityPatch"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Build.VERSION.SECURITY_PATCH else ""
        m["bootloader"] = Build.BOOTLOADER

        // Developer mode + USB debugging
        m["developerMode"] = try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) == 1
        } catch (_: Throwable) { false }
        m["usbDebugging"] = try {
            Settings.Global.getInt(context.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
        } catch (_: Throwable) { false }

        // Unknown sources policy (per-app since Android O — informational)
        m["unknownSourcesUnknown"] = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O

        // VPN active
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        var vpn = false
        try {
            val net = cm?.activeNetwork
            val cap = net?.let { cm.getNetworkCapabilities(it) }
            vpn = cap?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
        } catch (_: Throwable) { }
        m["vpnActive"] = vpn

        return m
    }
}
