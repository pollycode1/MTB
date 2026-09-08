import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class SettingsScreen extends StatefulWidget {
  final List<TaskItem> tasks;
  final int weeklyBudget;
  final String userName;
  final void Function(int budget, String name, bool clearedAll) onSave;

  const SettingsScreen({
    super.key,
    required this.tasks,
    required this.weeklyBudget,
    required this.userName,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _budgetCtrl;
  bool _clearedAll = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.userName);
    _budgetCtrl = TextEditingController(text: widget.weeklyBudget.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  int get _doneCnt  => widget.tasks.where((t) => t.done).length;
  int get _totalCnt => widget.tasks.length;

  void _save() {
    final budget = int.tryParse(_budgetCtrl.text) ?? widget.weeklyBudget;
    widget.onSave(budget, _nameCtrl.text.trim(), _clearedAll);
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

            // ── Budget ─────────────────────────────────────────────────────
            _sectionLabel('งบประมาณ'),
            _card(child: Column(children: [
              _fieldRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'งบรายสัปดาห์ (฿)',
                child: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _budgetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kCGoldDark, fontFamily: kMono),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 20),

            // ── Tasks ──────────────────────────────────────────────────────
            _sectionLabel('จัดการงาน'),
            _card(child: Column(children: [
              _infoRow(icon: Icons.task_alt_rounded, label: 'งานทั้งหมด', value: '$_totalCnt รายการ'),
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
