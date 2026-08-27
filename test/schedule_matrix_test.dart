import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:leitner_app/services/leitner_service.dart';

/// Đo giãn cách THẬT của lịch ôn.
///
/// Bảng lịch ở mục 3.1 chỉ cho biết khoảng cách TỐI THIỂU. Khoảng cách thật còn
/// phụ thuộc ngày trong tuần lúc thẻ lên hộp, nên phải đo mới biết. File này
/// vừa in bảng số liệu ra màn hình, vừa khoá lại các con số bằng expect để sau
/// này ai sửa bảng lịch thì test báo đỏ ngay.
const List<String> weekdayNames = [
  '', // weekday của Dart bắt đầu từ 1
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// Mã thẻ nhóm chẵn (ôn Thứ Bảy) và nhóm lẻ (ôn Chủ Nhật).
const String evenId = 'aa';
const String oddId = 'a';

/// Ngày Thứ Hai làm mốc, để duyệt đủ 7 thứ trong tuần.
final DateTime mondayAnchor = DateTime(2025, 5, 5);

void main() {
  final service = LeitnerService(random: Random(1));

  /// Giãn cách thật khi thẻ lên [box] vào ngày [start].
  int gapFrom(int box, DateTime start, String cardId) =>
      service.calculateNextReviewDate(box, cardId, start).difference(start).inDays;

  group('Dải giãn cách thật, xuất phát từ mọi thứ trong tuần', () {
    test('In bảng và khoá lại các con số', () {
      final buffer = StringBuffer();
      buffer.writeln();
      buffer.writeln('BẢNG GIÃN CÁCH THẬT (số ngày tới lần ôn kế tiếp)');
      buffer.writeln('=' * 78);
      buffer.writeln('Lên hộp vào  | Hộp 1 | Hộp 2 | Hộp 3 | Hộp 4 chẵn '
          '| Hộp 4 lẻ | Hộp 5*');
      buffer.writeln('-' * 78);

      // Gom lại để tính dải nhỏ nhất và lớn nhất của từng hộp.
      final gaps = <String, List<int>>{
        'box1': [],
        'box2': [],
        'box3': [],
        'box4even': [],
        'box4odd': [],
      };

      for (var offset = 0; offset < 7; offset++) {
        final start = mondayAnchor.add(Duration(days: offset));
        final g1 = gapFrom(1, start, evenId);
        final g2 = gapFrom(2, start, evenId);
        final g3 = gapFrom(3, start, evenId);
        final g4even = gapFrom(4, start, evenId);
        final g4odd = gapFrom(4, start, oddId);
        final g5 = gapFrom(5, start, evenId);

        gaps['box1']!.add(g1);
        gaps['box2']!.add(g2);
        gaps['box3']!.add(g3);
        gaps['box4even']!.add(g4even);
        gaps['box4odd']!.add(g4odd);

        buffer.writeln(
          '${weekdayNames[start.weekday].padRight(12)} | '
          '${g1.toString().padLeft(5)} | '
          '${g2.toString().padLeft(5)} | '
          '${g3.toString().padLeft(5)} | '
          '${g4even.toString().padLeft(10)} | '
          '${g4odd.toString().padLeft(8)} | '
          '${g5.toString().padLeft(5)}',
        );
      }

      buffer.writeln('-' * 78);
      buffer.writeln('* Hộp 5 phụ thuộc ngày trong THÁNG chứ không phải thứ '
          'trong tuần, nên cột này');
      buffer.writeln('  chỉ đúng cho tháng 5/2025; xem bảng riêng bên dưới.');
      buffer.writeln();

      for (final entry in gaps.entries) {
        final values = entry.value;
        buffer.writeln('${entry.key.padRight(10)} dải: '
            '${values.reduce(min)} đến ${values.reduce(max)} ngày');
      }
      stdout.write(buffer.toString());

      // Khoá lại các con số đo được.
      expect(gaps['box1'], everyElement(1), reason: 'Hộp 1 luôn đúng 1 ngày');
      expect(gaps['box2']!.reduce(min), 2);
      expect(gaps['box2']!.reduce(max), 4);
      expect(gaps['box3']!.reduce(min), 5);
      expect(gaps['box3']!.reduce(max), 11);
      expect(gaps['box4even']!.reduce(min), 12);
      expect(gaps['box4even']!.reduce(max), 18);
      expect(gaps['box4odd']!.reduce(min), 12);
      expect(gaps['box4odd']!.reduce(max), 18);
    });

    test('Hộp 5 phụ thuộc ngày trong tháng, đo trên trọn một năm', () {
      final buffer = StringBuffer();
      buffer.writeln();
      buffer.writeln('HỘP 5 — giãn cách theo ngày lên hộp (năm 2025)');
      buffer.writeln('=' * 50);

      final allGaps = <int>[];
      for (var month = 1; month <= 12; month++) {
        final monthGaps = <int>[];
        final daysInMonth = DateTime(2025, month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          monthGaps.add(gapFrom(5, DateTime(2025, month, day), evenId));
        }
        allGaps.addAll(monthGaps);
        buffer.writeln('Tháng ${month.toString().padLeft(2)}: '
            '${monthGaps.reduce(min)} đến ${monthGaps.reduce(max)} ngày');
      }
      buffer.writeln('-' * 50);
      buffer.writeln('Cả năm: ${allGaps.reduce(min)} đến '
          '${allGaps.reduce(max)} ngày');
      stdout.write(buffer.toString());

      expect(allGaps.reduce(min), 20);
      expect(allGaps.reduce(max), 50);
    });
  });

  group('Chuỗi giãn cách thật khi người học đi đúng lịch', () {
    test('Thẻ chỉ vào Hộp 4 từ Hộp 3, mà Hộp 3 chỉ ôn Thứ Ba', () {
      // Đây là mấu chốt: thẻ lên Hộp 4 khi trả lời ĐÚNG ở Hộp 3. Hộp 3 chỉ đến
      // hạn vào Thứ Ba, nên nếu người học ôn đúng hạn thì ngày lên Hộp 4 LUÔN
      // là Thứ Ba, chứ không phải một thứ bất kỳ.
      for (var offset = 0; offset < 7; offset++) {
        final start = mondayAnchor.add(Duration(days: offset));
        final box3Due = service.calculateNextReviewDate(3, evenId, start);
        expect(box3Due.weekday, DateTime.tuesday);
      }
    });

    test('Vào Hộp 4 từ Thứ Ba: nhóm chẵn 18 ngày, nhóm lẻ 12 ngày', () {
      // Thứ Ba cộng 12 ngày rơi vào Chủ Nhật. Nhóm lẻ ôn Chủ Nhật nên dừng ngay
      // tại đó — 12 ngày. Nhóm chẵn ôn Thứ Bảy nên phải đi tiếp 6 ngày nữa —
      // 18 ngày.
      for (var week = 0; week < 8; week++) {
        final tuesday = mondayAnchor.add(Duration(days: 1 + week * 7));
        expect(tuesday.weekday, DateTime.tuesday);

        expect(tuesday.add(const Duration(days: 12)).weekday, DateTime.sunday,
            reason: 'Thứ Ba cộng 12 ngày luôn là Chủ Nhật');

        expect(gapFrom(4, tuesday, evenId), 18,
            reason: 'Nhóm chẵn phải chờ tới Thứ Bảy');
        expect(gapFrom(4, tuesday, oddId), 12,
            reason: 'Nhóm lẻ dừng ngay tại Chủ Nhật thứ 12');
      }
    });

    test('Chuỗi đầy đủ từ lúc kích hoạt tới Hộp 5, đi đúng hạn', () {
      final buffer = StringBuffer();
      buffer.writeln();
      buffer.writeln('CHUỖI GIÃN CÁCH THẬT KHI ÔN ĐÚNG HẠN');
      buffer.writeln('=' * 72);
      buffer.writeln('Kích hoạt   | 1→2 | 2→3 | 3→4 chẵn | 3→4 lẻ '
          '| 4→5 chẵn | 4→5 lẻ | Tới Hộp 5');
      buffer.writeln('-' * 72);

      for (var offset = 0; offset < 7; offset++) {
        final activation = mondayAnchor.add(Duration(days: offset));

        // Thẻ mới kích hoạt đến hạn ngay hôm nay; trả lời đúng thì lên Hộp 2.
        final box2Due = service.calculateNextReviewDate(2, evenId, activation);
        // Ôn đúng hạn ở Hộp 2, trả lời đúng thì lên Hộp 3.
        final box3Due = service.calculateNextReviewDate(3, evenId, box2Due);
        // Ôn đúng hạn ở Hộp 3 (luôn Thứ Ba), trả lời đúng thì lên Hộp 4.
        final box4Even = service.calculateNextReviewDate(4, evenId, box3Due);
        final box4Odd = service.calculateNextReviewDate(4, oddId, box3Due);
        // Ôn đúng hạn ở Hộp 4, trả lời đúng thì lên Hộp 5 — đây là chặng cuối.
        final box5Even = service.calculateNextReviewDate(5, evenId, box4Even);
        final box5Odd = service.calculateNextReviewDate(5, oddId, box4Odd);

        final g12 = box2Due.difference(activation).inDays;
        final g23 = box3Due.difference(box2Due).inDays;
        final g34Even = box4Even.difference(box3Due).inDays;
        final g34Odd = box4Odd.difference(box3Due).inDays;
        final g45Even = box5Even.difference(box4Even).inDays;
        final g45Odd = box5Odd.difference(box4Odd).inDays;
        // Tổng số ngày từ lúc kích hoạt tới lúc thẻ đặt chân vào Hộp 5.
        final totalEven = box4Even.difference(activation).inDays;

        buffer.writeln(
          '${weekdayNames[activation.weekday].padRight(11)} | '
          '${g12.toString().padLeft(3)} | '
          '${g23.toString().padLeft(3)} | '
          '${g34Even.toString().padLeft(8)} | '
          '${g34Odd.toString().padLeft(6)} | '
          '${g45Even.toString().padLeft(8)} | '
          '${g45Odd.toString().padLeft(6)} | '
          '${totalEven.toString().padLeft(9)}',
        );

        // Ôn đúng hạn thì Hộp 3 luôn rơi vào Thứ Ba, nên bước 3→4 là hằng số:
        // Thứ Ba cộng 12 ngày là Chủ Nhật, nhóm lẻ dừng ngay tại đó (12 ngày),
        // nhóm chẵn phải đi tiếp tới Thứ Bảy (18 ngày).
        expect(box3Due.weekday, DateTime.tuesday);
        expect(g34Even, 18);
        expect(g34Odd, 12);
      }
      buffer.writeln('-' * 72);
      stdout.write(buffer.toString());
    });
  });
}
