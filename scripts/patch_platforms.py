#!/usr/bin/env python3
"""Run after `flutter create .` - adds permissions, background audio,
Picture-in-Picture (floating window) and app name for Android + iOS."""
import glob, pathlib, plistlib, re

# ---------------------------------------------------------------- Android
manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = manifest.read_text()

perms = ['INTERNET', 'WAKE_LOCK', 'FOREGROUND_SERVICE',
         'FOREGROUND_SERVICE_MEDIA_PLAYBACK', 'POST_NOTIFICATIONS']
add = ''.join(f'    <uses-permission android:name="android.permission.{p}"/>\n'
              for p in perms if f'android.permission.{p}"' not in s)
s = s.replace('<application', add + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="PenTube"', s, count=1)
if 'supportsPictureInPicture' not in s:
    s = s.replace('<activity', '<activity\n            android:supportsPictureInPicture="true"', 1)
if 'com.ryanheise.audioservice.AudioService' not in s:
    svc = '''
        <service android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>
        <receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true" tools:ignore="Instantiatable">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>
    '''
    s = s.replace('</application>', svc + '</application>', 1)
if 'xmlns:tools' not in s:
    s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ', 1)
# allow plain http to the on-device video proxy (127.0.0.1 only)
xml = pathlib.Path('android/app/src/main/res/xml')
xml.mkdir(parents=True, exist_ok=True)
(xml / 'network_security_config.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
''')
if 'networkSecurityConfig' not in s:
    s = s.replace('<application', '<application android:networkSecurityConfig="@xml/network_security_config"', 1)
manifest.write_text(s)

kt = glob.glob('android/app/src/main/**/MainActivity.kt', recursive=True)
assert kt, 'MainActivity.kt not found'
path = pathlib.Path(kt[0])
pkg = re.search(r'^package\s+([\w.]+)', path.read_text(), re.M).group(1)
path.write_text(f'''package {pkg}

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {{
    private var channel: MethodChannel? = null
    private var armed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {{
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.pentube/pip")
        channel?.setMethodCallHandler {{ call, result ->
            when (call.method) {{
                "supported" -> result.success(
                    Build.VERSION.SDK_INT >= 26 &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
                "arm" -> {{
                    armed = call.arguments as? Boolean ?: false
                    updateParams()
                    result.success(null)
                }}
                "enter" -> result.success(enter())
                else -> result.notImplemented()
            }}
        }}
    }}

    private fun params(): PictureInPictureParams {{
        val b = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= 31) {{
            b.setAutoEnterEnabled(armed)
            b.setSeamlessResizeEnabled(true)
        }}
        return b.build()
    }}

    private fun updateParams() {{
        if (Build.VERSION.SDK_INT >= 26) {{
            try {{ setPictureInPictureParams(params()) }} catch (e: Exception) {{ }}
        }}
    }}

    private fun enter(): Boolean {{
        if (Build.VERSION.SDK_INT < 26) return false
        return try {{ enterPictureInPictureMode(params()) }} catch (e: Exception) {{ false }}
    }}

    override fun onUserLeaveHint() {{
        super.onUserLeaveHint()
        if (armed && Build.VERSION.SDK_INT in 26..30) enter()
    }}

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {{
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }}
}}
''')

# -------------------------------------------------------------------- iOS
plist = pathlib.Path('ios/Runner/Info.plist')
if plist.exists():
    d = plistlib.loads(plist.read_bytes())
    d['CFBundleDisplayName'] = 'PenTube'
    d['CFBundleName'] = 'PenTube'
    d['UIBackgroundModes'] = ['audio']
    d['NSAppTransportSecurity'] = {'NSAllowsLocalNetworking': True}
    d['CFBundleLocalizations'] = ['en', 'th']
    plist.write_bytes(plistlib.dumps(d))

print('platform patch done')
