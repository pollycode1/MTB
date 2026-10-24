import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

// เรียก Claude ผ่าน HTTP ตรง (Dart ไม่มี SDK ทางการ) และบังคับให้ตอบเป็น JSON ตาม schema
class AiService {
  static const model = 'claude-haiku-5-5';
  static const _keyPref = 'settings_ai_key';

  static Future<String> apiKey() async =>
      (await SharedPreferences.getInstance()).getString(_keyPref) ?? '';

  static Future<void> setApiKey(String key) async =>
      (await SharedPreferences.getInstance()).setString(_keyPref, key.trim());

  static Future<bool> hasKey() async => (await apiKey()).isNotEmpty;

  static Future<Map<String, dynamic>> askJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    int maxTokens = 4096,
  }) async {
    final key = await apiKey();
    if (key.isEmpty) throw AiException('ยังไม่ได้ใส่ API key (ตั้งค่า → AI)');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse('https://api.anthropic.com/v1/messages'));
      req.headers
        ..set('content-type', 'application/json')
        ..set('x-api-key', key)
        ..set('anthropic-version', '2023-06-01');
      req.add(utf8.encode(jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [{'role': 'user', 'content': prompt}],
        'output_config': {
          'effort': 'low', // งานจัดหมวด/เลือกงาน ไม่ต้องคิดลึก ประหยัดและเร็ว
          'format': {'type': 'json_schema', 'schema': schema},
        },
      })));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body) as Map<String, dynamic>;
      if (res.statusCode != 200) {
        final msg = (j['error'] as Map?)?['message'] ?? body;
        throw AiException(switch (res.statusCode) {
          401 => 'API key ไม่ถูกต้อง',
          429 => 'เรียกถี่เกินไป ลองใหม่อีกสักครู่',
          529 || 500 || 503 => 'เซิร์ฟเวอร์ AI ไม่ว่าง ลองใหม่อีกครั้ง',
          _ => 'AI ผิดพลาด (${res.statusCode}): $msg',
        });
      }
      final stop = j['stop_reason'];
      if (stop == 'refusal') throw AiException('AI ปฏิเสธคำขอนี้');
      if (stop == 'max_tokens') throw AiException('คำตอบยาวเกินกำหนด ลองใหม่');
      final text = (j['content'] as List).firstWhere((b) => b['type'] == 'text')['text'] as String;
      return jsonDecode(text) as Map<String, dynamic>;
    } on SocketException {
      throw AiException('เชื่อมต่ออินเทอร์เน็ตไม่ได้');
    } on TimeoutException {
      throw AiException('AI ตอบช้าเกินไป ลองใหม่');
    } finally {
      client.close();
    }
  }
}

// ── ข้อมูลงานแบบย่อสำหรับส่งให้ AI ─────────────────────────────────────────────────
String _d(DateTime? d) => d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> taskForAi(TaskItem t) => {
  'id': t.id,
  'title': t.title,
  if (t.meta.isNotEmpty) 'note': t.meta,
  if (t.area != null) 'area': t.area,
  if (t.tags.isNotEmpty) 'tags': t.tags,
  'priority': t.priority, // 1 สูง 2 กลาง 3 ต่ำ
  if (t.deadline != null) 'deadline': _d(t.deadline),
  if (t.plannedFor != null) 'plannedFor': _d(t.plannedFor),
  if (t.postponeCount > 0) 'postponed': t.postponeCount,
  if (t.subTasks.isNotEmpty) 'steps': '${t.subTasks.where((s) => s.done).length}/${t.subTasks.length}',
};

String todayLine() {
  final n = DateTime.now();
  const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
  return 'วันนี้คือวัน${days[n.weekday - 1]}ที่ ${_d(n)}';
}

const aiSystem = 'คุณเป็นผู้ช่วยจัดการงานของครูคณิตศาสตร์ระดับมัธยมในไทย ผู้ใช้มีปัญหาขี้เกียจและผัดวันประกันพรุ่ง '
    'ช่วยให้ลงมือได้จริง: เลือกน้อยแต่ชัด ขั้นแรกต้องเล็กจนเริ่มได้ใน 5 นาที ตอบเป็นภาษาไทย สั้น กระชับ ไม่เทศนา';

// แท็ก 2-4 อันให้ครอบคลุมหลายมุม (ก่อนหน้านี้ AI มักใส่แค่ 1 เพราะถูกสั่งให้ใช้แท็กเดิมก่อนเป็นหลัก)
const aiTagRule = 'ใส่ 2-4 แท็กให้ครอบคลุมหลายมุมของงาน: (1) ประเภทงาน เช่น ตรวจงาน ออกข้อสอบ ทำสื่อ เอกสาร ประชุม '
    '(2) ห้อง/ระดับชั้น/วิชา ถ้ามีในข้อความ เช่น ม.2 3/2 (3) คนหรือกลุ่มที่เกี่ยวข้อง เช่น ผู้ปกครอง ฝ่ายวิชาการ '
    '(4) ลักษณะงาน เช่น ด่วน รอคนอื่น ทำซ้ำ — ถ้าแท็กที่มีอยู่ความหมายตรงให้ใช้ชื่อเดิม ถ้าไม่มีให้ตั้งใหม่ได้ สั้น 1-2 คำ '
    'ห้ามซ้ำกับชื่อหมวด ห้ามใส่ # นำหน้า';

// ── พูดแทนพิมพ์: แยกข้อความเสียงเป็นหลายงาน (แต่ละงานไปจัดหมวด/วันส่งต่อด้วย _aiTriage) ──────────
Future<List<String>> splitSpokenTasks(String text) async {
  final r = await AiService.askJson(
    system: aiSystem,
    prompt: '${todayLine()}\nผู้ใช้พูดสิ่งที่ต้องทำ (ถอดเสียงอัตโนมัติ อาจสะกดผิด/ไม่มีวรรคตอน):\n"$text"\n\n'
        'แยกเป็นรายการงาน 1 งานต่อ 1 รายการ เขียนชื่องานสั้น กระชับ แก้คำที่ถอดเสียงผิดให้ถูก '
        'คงวัน/เวลา/ห้อง/ชื่อคนที่พูดถึงไว้ในชื่องาน ห้ามเพิ่มงานที่ไม่ได้พูด ถ้าพูดเรื่องเดียวให้ตอบรายการเดียว',
    schema: {
      'type': 'object',
      'properties': {'tasks': {'type': 'array', 'items': {'type': 'string'}}},
      'required': ['tasks'],
      'additionalProperties': false,
    },
  );
  return cleanSplit(r['tasks'] as List? ?? [], fallback: text);
}

// ตัดรายการว่าง/ซ้ำ ไม่เกิน 10 งาน · AI ไม่ได้อะไรเลย → ใช้ข้อความเดิมเป็นงานเดียว
List<String> cleanSplit(List raw, {required String fallback}) {
  final out = raw.map((x) => '$x'.trim()).where((x) => x.isNotEmpty).toSet().take(10).toList();
  return out.isEmpty ? [fallback] : out;
}
