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
  static const Map<int, String> scheduleLabels = {
    1: 'Mỗi ngày',
    2: 'T2 · T4 · T6',
    3: 'Thứ Ba',
    4: 'Cuối tuần',
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
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
          Text(
            'Hộp $boxNumber',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$cardCount',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: foreground,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            scheduleLabels[boxNumber] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: foreground.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}
