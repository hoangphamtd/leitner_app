import 'package:flutter/material.dart';

/// Một khối vuông đại diện cho một hộp Leitner ở màn hình Tổng quan.
///
/// Khối được làm nổi bật khi hộp có thẻ đến hạn hôm nay — đó là tín hiệu chính
/// để người học biết hôm nay cần chú ý hộp nào.
class BoxTile extends StatelessWidget {
  final int boxNumber;
  final int cardCount;

  /// Hộp này có thẻ đến hạn hôm nay hay không.
  final bool isDue;

  const BoxTile({
    super.key,
    required this.boxNumber,
    required this.cardCount,
    required this.isDue,
  });

  /// Lịch ôn của hộp, hiển thị ngay trên khối để người học nắm được nhịp.
  ///
  /// Nhãn phải THẬT NGẮN. Màn hình iPhone thường rộng 390, trừ lề còn chia cho
  /// năm ô nên mỗi ô chỉ khoảng 66 điểm ảnh. Nhãn dài hơn sẽ xuống dòng, đè lên
  /// nhau và tràn khỏi ô — đã xảy ra thật với "Mỗi ngày" và "T2 · T4 · T6".
  static const Map<int, String> scheduleLabels = {
    1: 'Hằng ngày',
    2: 'T2·4·6',
    3: 'Thứ Ba',
    4: 'T7 · CN',
    5: 'Ngày 15',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Hộp đến hạn dùng màu chính đậm để bật hẳn lên; hộp còn lại dùng nền dịu
    // để không tranh sự chú ý.
    final background = isDue
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = isDue
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: isDue
            ? Border.all(color: scheme.primary, width: 2)
            : Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cả ba dòng đều bọc trong FittedBox: ô quá hẹp thì chữ tự thu nhỏ
          // lại cho vừa MỘT dòng, thay vì xuống dòng rồi tràn ra ngoài.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Hộp $boxNumber',
              maxLines: 1,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$cardCount',
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              scheduleLabels[boxNumber] ?? '',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: foreground.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
