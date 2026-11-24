<p align="center"><img src="assets/icon/icon.png" width="120" alt="PenTube"></p>

# PenTube

**EN** — PenTube is **YouTube without ads**. Same look and feel, search and watch anything, no ads, no account, light on data and battery, smooth even on low-end phones.

**TH** — PenTube คือ **YouTube แบบไม่มีโฆษณา** หน้าตาและการใช้งานเหมือนยูทูป ค้นหาและดูได้ ไม่มีโฆษณา ไม่ต้องล็อกอิน ใช้เน็ตและแบตน้อย ลื่นแม้มือถือสเปกต่ำ

> Unofficial client. Not affiliated with YouTube or Google. · แอปไม่เป็นทางการ ไม่เกี่ยวข้องกับ YouTube หรือ Google

## Features / ฟีเจอร์

| EN | TH |
|---|---|
| YouTube-style home, categories, search with suggestions | หน้าแรกสไตล์ YouTube หมวดหมู่ ค้นหาพร้อมคำแนะนำ |
| Watch videos, related videos, autoplay next, channel uploads | ดูวิดีโอ วิดีโอที่เกี่ยวข้อง เล่นคลิปถัดไปอัตโนมัติ ดูคลิปของช่อง |
| No ads, no login, no tracking | ไม่มีโฆษณา ไม่ต้องล็อกอิน ไม่ติดตามผู้ใช้ |
| Floating window (Picture-in-Picture) when you press Home (Android) | หน้าต่างลอยเมื่อกด Home (Android) |
| Keeps playing audio with screen off / app closed, lock-screen controls | เล่นเสียงต่อเมื่อปิดหน้าจอ/ออกจากแอป มีปุ่มควบคุมที่ล็อกสกรีน |
| "Listen only" mode: audio stream only, saves a lot of data | โหมดฟังอย่างเดียว ใช้เน็ตน้อยมาก |
| Saver mode: small thumbnails, low-bitrate audio, limited paging, small RAM cache | โหมดประหยัด: ภาพเล็ก เสียงบิตเรตต่ำ โหลดน้อยลง ใช้แรมน้อย |
| Defaults to 360p, pick 144p/360p/720p | เริ่มที่ 360p เลือก 144p/360p/720p ได้ |
| History, saved videos, recent searches (stored only on your phone) | ประวัติ วิดีโอที่บันทึก ค้นหาล่าสุด (เก็บในเครื่องเท่านั้น) |
| Thai and English UI (auto / manual), dark and light theme | ภาษาไทย/อังกฤษ (อัตโนมัติ/เลือกเอง) ธีมมืด/สว่าง |

## Download / ดาวน์โหลด

Go to **Releases**.

- Android: `PenTube-android-arm64-v8a.apk` for most phones (`universal` works on all).
- iOS: `PenTube-ios-unsigned.ipa` is **unsigned** — install with AltStore / Sideloadly / TrollStore (needs your Apple ID or a jailbreak-free sideload tool).

ไปที่แท็บ **Releases** — Android ใช้ `arm64-v8a` กับมือถือส่วนใหญ่ (ถ้าไม่แน่ใจใช้ `universal`) / iOS เป็นไฟล์ที่ยังไม่ได้เซ็น ต้องลงด้วย AltStore / Sideloadly / TrollStore

## Build with GitHub / สร้างด้วย GitHub

1. Create a new GitHub repo and upload everything in this folder. / สร้าง repo ใหม่แล้วอัปโหลดทุกไฟล์ในโฟลเดอร์นี้
2. **Actions → Build PenTube → Run workflow** (APK + IPA appear as artifacts). / ไปที่ Actions แล้วกด Run workflow
3. For a public release, push a tag / ถ้าจะออก Release ให้ push tag:
   ```bash
   git tag v1.0.0 && git push origin v1.0.0
   ```
   The workflow builds Android + iOS and attaches them to a GitHub Release. / workflow จะ build ทั้ง Android และ iOS แล้วแนบใน Release ให้อัตโนมัติ

The `android/` and `ios/` folders are generated in CI by `flutter create` and patched by `scripts/patch_platforms.py` (permissions, background audio, floating window, app name). To build locally:

```bash
flutter create . --project-name pentube --org app.pentube --platforms=android,ios
python3 scripts/patch_platforms.py
flutter pub get && dart run flutter_launcher_icons
flutter run
```

## Tips / ข้อแนะนำ

- Android 13+: allow notifications so the music controls show. / อนุญาตการแจ้งเตือนเพื่อให้เห็นปุ่มควบคุมเพลง
- Some phones kill background apps: set PenTube to "Unrestricted" battery. / บางรุ่นฆ่าแอปเบื้องหลัง ให้ตั้งแบตเตอรี่ของ PenTube เป็นไม่จำกัด
- Floating window is Android only (8.0+). On iOS, leaving the app switches to background audio. / หน้าต่างลอยมีเฉพาะ Android ส่วน iOS เมื่อออกจากแอปจะเล่นเฉพาะเสียงต่อ
- If playback or search stops working one day, YouTube changed something: update `youtube_explode_dart` in `pubspec.yaml` and rebuild. / ถ้าวันหนึ่งเล่นไม่ได้ แปลว่า YouTube เปลี่ยนระบบ ให้อัปเดตแพ็กเกจ `youtube_explode_dart` แล้ว build ใหม่

## How it saves data and battery / ประหยัดเน็ตและแบตยังไง

- Progressive 360p streams by default, thumbnails 320x180 only. / เริ่มที่ 360p ภาพปก 320x180
- App leaves the screen → video is released and only the audio stream plays. / ออกจากหน้าจอ ระบบปล่อยวิดีโอแล้วเล่นเฉพาะเสียง
- Lazy lists, small image cache, search results cached in memory. / ลิสต์โหลดทีละส่วน แคชภาพเล็ก แคชผลค้นหา
