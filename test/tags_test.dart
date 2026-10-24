import 'package:flutter_test/flutter_test.dart' hide Tags;
import 'package:mtb/models.dart';
import 'package:mtb/tags.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('removing a tag everywhere clears it from every task and the registry', () {
    SharedPreferences.setMockInitialValues({});
    Tags.list = ['ด่วน'];
    final a = TaskItem(title: 'a', tag: 'ตรวจงาน'), b = TaskItem(title: 'b', tag: 'ตรวจงาน'), c = TaskItem(title: 'c', tag: 'ด่วน');

    Tags.mergeFrom([a, b, c]); // แท็กจากงานเก่าเข้ารายการกลาง ไม่ซ้ำ
    expect(Tags.list, ['ด่วน', 'ตรวจงาน']);

    expect(Tags.removeEverywhere('ตรวจงาน', [a, b, c]), 2);
    expect([a.tag, b.tag, c.tag], [null, null, 'ด่วน']);
    expect(Tags.list, ['ด่วน']);
  });
}
