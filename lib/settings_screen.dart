import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'ai_service.dart';
import 'attachments.dart';
import 'backup.dart';
import 'categories.dart';
import 'models.dart';

class SettingsScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final String userName;
  final void Function(String name, bool clearedAll) onSave;
  final VoidCallback onTasksChanged; // แก้หมวดแล้วงานเปลี่ยนตาม
  final void Function(List<TaskItem> tasks) onImport; // กู้คืน: แทนที่งานทั้งหมด

  const SettingsScreen({
    super.key,
    required this.tasks,
    required this.userName,
    required this.onSave,
    required this.onImport,
    required this.onTasksChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  bool _clearedAll = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName);
    AiService.hasKey().then((v) { if (mounted) setState(() => _hasKey = v); });
  }

  Future<void> _editKey() async {
    final ctrl = TextEditingController(text: await AiService.apiKey());
    if (!mounted) return;
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Claude API key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('สร้างได้ที่ platform.claude.com → API keys\nเก็บไว้ในเครื่องนี้เท่านั้น', style: TextStyle(fontSize: 12, color: kCText.withValues(alpha: .55))),
          const SizedBox(height: 10),
          TextField(controller: ctrl, obscureText: true, style: const TextStyle(color: kCText),
            decoration: InputDecoration(hintText: 'sk-ant-…', hintStyle: TextStyle(color: kCText.withValues(alpha: .3)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('ลบ key', style: TextStyle(color: kCRed))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('บันทึก', style: TextStyle(color: kCGreenDk, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (key == null) return;
    await AiService.setApiKey(key);
    if (mounted) setState(() => _hasKey = key.isNotEmpty);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _doneCnt  => widget.tasks.where((t) => t.done).length;
  int get _totalCnt => widget.tasks.length;

  void _save() {
    widget.onSave(_nameCtrl.text.trim(), _clearedAll);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kCBg,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: kCText.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kCText),
              ),
            ),
            const SizedBox(width: 14),
            const Text('ตั้งค่า', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kCText)),
            const Spacer(),
            GestureDetector(
              onTap: _save,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: kCGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('บันทึก', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),

        // ── Content ──────────────────────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Profile ────────────────────────────────────────────────────
            _sectionLabel('โปรไฟล์'),
            _card(child: Column(children: [
              _fieldRow(
                icon: Icons.person_outline_rounded,
                label: 'ชื่อ',
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 14, color: kCText),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'ชื่อของคุณ',
                    hintStyle: TextStyle(color: Color(0x5520291F)),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 20),

            // ── Tasks ──────────────────────────────────────────────────────
            _sectionLabel('จัดการงาน'),
            _card(child: Column(children: [
              _actionRow(
                icon: Icons.folder_outlined,
                label: 'จัดการหมวดหมู่ (${Categories.list.length})',
                color: kCText,
                done: false,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoriesScreen(
                  tasks: widget.tasks, onTasksChanged: widget.onTasksChanged,
                ))).then((_) { if (mounted) setState(() {}); }),
              ),
              _divider(),
              _infoRow(icon: Icons.task_alt_rounded, label: 'งานทั้งหมด', value: '$_totalCnt รายการ'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text('ไฟล์แนบเก็บที่: ${Attachments.rootPath.contains('/Android/') ? 'Android/${Attachments.rootPath.split('/Android/').last}' : Attachments.rootPath}',
                  style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
              ),
              _infoRow(icon: Icons.check_circle_outline_rounded, label: 'เสร็จแล้ว (ประวัติ)', value: '$_doneCnt รายการ'),
              if (_totalCnt > 0) ...[
                _divider(),
                _actionRow(
                  icon: Icons.delete_sweep_outlined,
                  label: 'ล้างงานทั้งหมด',
                  color: kCRed,
                  done: _clearedAll,
                  onTap: () async {
                    final ok = await _confirm('ล้างงานทั้งหมด?', 'งาน $_totalCnt รายการจะถูกลบถาวร');
                    if (ok && mounted) setState(() => _clearedAll = true);
                  },
                ),
              ],
            ])),
            const SizedBox(height: 20),

            // ── AI ─────────────────────────────────────────────────────────
            _sectionLabel('AI (Claude Haiku 5.5)'),
            _card(child: Column(children: [
              _actionRow(
                icon: Icons.key_rounded,
                label: _hasKey ? 'ใส่ API key แล้ว · แตะเพื่อเปลี่ยน' : 'ใส่ API key เพื่อเปิดใช้ AI',
                color: _hasKey ? kCGreenDk : kCText,
                done: false,
                onTap: _editKey,
              ),
            ])),
            const SizedBox(height: 20),

            // ── Backup ─────────────────────────────────────────────────────
            _sectionLabel('สำรองข้อมูล'),
            _card(child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text('สำรองอัตโนมัติวันละไฟล์ (รวมไฟล์แนบ) เก็บ 7 วันล่าสุดที่:\n'
                    '${AutoBackup.lastPath ?? '${AutoBackup.publicDir}/'}',
                  style: TextStyle(fontSize: 11.5, color: kCText.withValues(alpha: .45))),
              ),
              _actionRow(
                icon: Icons.file_open_outlined,
                label: 'กู้คืนจากไฟล์สำรอง (แทนที่งานทั้งหมด)',
                color: kCText,
                done: false,
                onTap: () async {
                  final picked = await FilePicker.pickFiles();
                  if (picked.isEmpty) return;
                  await _restore(await picked.first.xFile.readAsString());
                },
              ),
              _divider(),
              _actionRow(
                icon: Icons.copy_all_rounded,
                label: 'คัดลอกข้อมูลสำรอง (วางเก็บไว้ในโน้ตได้)',
                color: kCText,
                done: false,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: buildBackup(widget.tasks)));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('คัดลอกงาน $_totalCnt รายการแล้ว')));
                  }
                },
              ),
              _divider(),
              _actionRow(
                icon: Icons.restore_rounded,
                label: 'กู้คืนจากคลิปบอร์ด (แทนที่งานทั้งหมด)',
                color: kCText,
                done: false,
                onTap: () async =>
                    _restore((await Clipboard.getData(Clipboard.kTextPlain))?.text ?? ''),
              ),
            ])),
            const SizedBox(height: 20),

            // ── About ──────────────────────────────────────────────────────
            _sectionLabel('เกี่ยวกับ'),
            _card(child: Column(children: [
              _infoRow(icon: Icons.info_outline_rounded, label: 'เวอร์ชัน', value: '1.0.0'),
              _divider(),
              _infoRow(icon: Icons.palette_outlined, label: 'ธีม', value: 'Forest Cream'),
            ])),

          ]),
        )),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
      color: kCText.withValues(alpha: .4), letterSpacing: .8)),
  );

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: kCSurf,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: kCText.withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: child,
  );

  Widget _divider() => Divider(height: 1, indent: 48, color: kCText.withValues(alpha: .07));

  Widget _fieldRow({required IconData icon, required String label, required Widget child}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, size: 18, color: kCGreen),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
      const SizedBox(width: 12),
      Expanded(child: child),
    ]),
  );

  Widget _infoRow({required IconData icon, required String label, required String value}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, size: 18, color: kCGreen),
      const SizedBox(width: 12),
      Text(label, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: kCText)),
    ]),
  );

  Widget _actionRow({
    required IconData icon,
    required String label,
    required Color color,
    required bool done,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: done ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : icon, size: 18, color: done ? kCGreen : color),
        const SizedBox(width: 12),
        Text(done ? 'จะลบเมื่อกด บันทึก' : label,
          style: TextStyle(fontSize: 13.5, color: done ? kCGreen : color,
            fontWeight: done ? FontWeight.w500 : FontWeight.w400)),
      ]),
    ),
  );

  Future<void> _restore(String text) async {
    final restored = parseBackup(text);
    if (!mounted) return;
    if (restored == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่ใช่ข้อมูลสำรองของ MTB')));
      return;
    }
    final ok = await _confirm('กู้คืนข้อมูล?', 'งานปัจจุบัน $_totalCnt รายการจะถูกแทนที่ด้วย ${restored.length} รายการจากข้อมูลสำรอง');
    if (!ok) return;
    await AutoBackup.restoreFiles(text);
    if (!mounted) return;
    widget.onImport(restored);
    Navigator.pop(context);
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCSurf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kCText)),
        content: Text(body, style: TextStyle(fontSize: 13.5, color: kCText.withValues(alpha: .6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('ยกเลิก', style: TextStyle(color: kCText.withValues(alpha: .5)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: kCRed, fontWeight: FontWeight.w700))),
        ],
      ),
    ) ?? false;
  }
}
