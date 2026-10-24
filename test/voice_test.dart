import 'package:flutter_test/flutter_test.dart';
import 'package:mtb/ai_service.dart';
import 'package:mtb/models.dart';

void main() {
  test('spoken task split cleanup and aiSplit round-trip', () {
    expect(cleanSplit([' ตรวจการบ้าน ม.2/3 ', '', 'ตรวจการบ้าน ม.2/3', 'โทรหาผู้ปกครอง'], fallback: 'x'),
        ['ตรวจการบ้าน ม.2/3', 'โทรหาผู้ปกครอง']);
    expect(cleanSplit([], fallback: 'พูดอะไรสักอย่าง'), ['พูดอะไรสักอย่าง']);
    expect(cleanSplit(List.generate(15, (i) => 'งาน $i'), fallback: 'x').length, 10);
    expect(TaskItem.fromJson(TaskItem(title: 'a', aiSplit: true).toJson()).aiSplit, true);
    expect(TaskItem(title: 'b').toJson().containsKey('aiSplit'), false);
  });
}
