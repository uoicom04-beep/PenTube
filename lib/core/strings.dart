import 'settings.dart';

class S {
  static String t(String k) {
    final m = _m[Settings.I.code] ?? _m['en']!;
    return m[k] ?? _m['en']![k] ?? k;
  }

  static const Map<String, Map<String, String>> _m = {
    'en': {
      'tagline': 'YouTube without ads',
      'home': 'Home', 'library': 'Library', 'settings': 'Settings',
      'searchHint': 'Search PenTube', 'recent': 'Recent searches',
      'history': 'History', 'saved': 'Saved', 'clear': 'Clear',
      'noHistory': 'Nothing watched yet', 'noSaved': 'No saved videos',
      'language': 'Language', 'auto': 'Auto', 'theme': 'Theme', 'dark': 'Dark', 'light': 'Light',
      'saver': 'Saver mode', 'saverDesc': 'Uses less data, battery and memory',
      'quality': 'Default video quality', 'leaveMode': 'When leaving the app',
      'modePip': 'Floating window', 'modeAudio': 'Keep playing audio only', 'modeStop': 'Pause',
      'autoplay': 'Autoplay next video',
      'about': 'About',
      'aboutText': 'PenTube is YouTube without ads. Unofficial client, not affiliated with YouTube or Google.',
      'retry': 'Retry', 'error': 'Something went wrong', 'noResults': 'No results',
      'related': 'Related videos', 'loadRelated': 'Show related videos',
      'listenOnly': 'Listen only (saves data)', 'watchVideo': 'Watch video',
      'save': 'Save', 'copyLink': 'Copy link', 'copied': 'Link copied',
      'views': 'views', 'floating': 'Floating window', 'live': 'LIVE',
      'c_all': 'All', 'c_music': 'Music', 'c_gaming': 'Gaming', 'c_news': 'News',
      'c_movies': 'Movies', 'c_sports': 'Sports', 'c_learn': 'Learning',
      'c_cook': 'Cooking', 'c_tech': 'Tech',
    },
    'th': {
      'tagline': 'YouTube แบบไม่มีโฆษณา',
      'home': 'หน้าแรก', 'library': 'คลังของฉัน', 'settings': 'ตั้งค่า',
      'searchHint': 'ค้นหาใน PenTube', 'recent': 'ค้นหาล่าสุด',
      'history': 'ประวัติ', 'saved': 'บันทึกไว้', 'clear': 'ล้าง',
      'noHistory': 'ยังไม่มีประวัติการดู', 'noSaved': 'ยังไม่มีวิดีโอที่บันทึก',
      'language': 'ภาษา', 'auto': 'อัตโนมัติ', 'theme': 'ธีม', 'dark': 'มืด', 'light': 'สว่าง',
      'saver': 'โหมดประหยัด', 'saverDesc': 'ใช้เน็ต แบต และแรมน้อยลง',
      'quality': 'คุณภาพวิดีโอเริ่มต้น', 'leaveMode': 'เมื่อออกจากแอป',
      'modePip': 'หน้าต่างลอย', 'modeAudio': 'เล่นต่อเฉพาะเสียง', 'modeStop': 'หยุดชั่วคราว',
      'autoplay': 'เล่นคลิปถัดไปอัตโนมัติ',
      'about': 'เกี่ยวกับ',
      'aboutText': 'PenTube คือ YouTube แบบไม่มีโฆษณา เป็นแอปไม่เป็นทางการ ไม่เกี่ยวข้องกับ YouTube หรือ Google',
      'retry': 'ลองใหม่', 'error': 'เกิดข้อผิดพลาด', 'noResults': 'ไม่พบผลลัพธ์',
      'related': 'วิดีโอที่เกี่ยวข้อง', 'loadRelated': 'แสดงวิดีโอที่เกี่ยวข้อง',
      'listenOnly': 'ฟังอย่างเดียว (ประหยัดเน็ต)', 'watchVideo': 'ดูวิดีโอ',
      'save': 'บันทึก', 'copyLink': 'คัดลอกลิงก์', 'copied': 'คัดลอกลิงก์แล้ว',
      'views': 'ครั้ง', 'floating': 'หน้าต่างลอย', 'live': 'สด',
      'c_all': 'ทั้งหมด', 'c_music': 'เพลง', 'c_gaming': 'เกม', 'c_news': 'ข่าว',
      'c_movies': 'หนัง', 'c_sports': 'กีฬา', 'c_learn': 'เรียนรู้',
      'c_cook': 'ทำอาหาร', 'c_tech': 'เทค',
    },
  };
}
