import 'package:flutter/material.dart';

/// Nền tảng di động mà người dùng đang mở app.
enum MobilePlatform { ios, android, other }

/// Bảng hướng dẫn thêm app vào màn hình chính.
///
/// Hiện dưới dạng bảng trượt từ đáy lên thay vì một màn hình riêng: người học
/// vẫn thấy app phía sau nên hiểu ngay đây là lời mời chứ không phải một bước
/// bắt buộc mới qua được.
class InstallGuideSheet extends StatelessWidget {
  final MobilePlatform platform;

  const InstallGuideSheet({super.key, required this.platform});

  /// Mở bảng hướng dẫn. Trả về true nếu người dùng chọn bỏ qua.
  static Future<bool?> show(BuildContext context, MobilePlatform platform) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InstallGuideSheet(platform: platform),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_to_home_screen_rounded,
                  size: 32,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thêm vào màn hình chính',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Nói thẳng cái mất mát, vì đây là lý do thật sự khiến việc cài đặt
            // đáng làm — không phải để app trông "xịn" hơn.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu chỉ mở bằng trình duyệt, tiến độ học có thể bị trình '
                      'duyệt xoá khi máy hết dung lượng hoặc khi bạn dọn dữ liệu '
                      'duyệt web. Cài vào màn hình chính thì dữ liệu được giữ '
                      'chắc chắn hơn nhiều.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._buildSteps(context),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('ĐỂ SAU'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('ĐÃ HIỂU'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Các bước cài, khác nhau hẳn giữa hai hệ điều hành.
  List<Widget> _buildSteps(BuildContext context) {
    final steps = switch (platform) {
      // Safari trên iOS không hỗ trợ lời mời cài tự động, buộc phải hướng dẫn
      // tay. Nút Chia sẻ nằm ở thanh dưới trên iPhone.
      MobilePlatform.ios => const [
        (Icons.ios_share_rounded, 'Bấm nút Chia sẻ ở thanh dưới của Safari'),
        (Icons.arrow_downward_rounded, 'Kéo xuống trong bảng vừa hiện ra'),
        (
          Icons.add_box_outlined,
          'Chọn "Thêm vào MH chính" (Add to Home Screen)',
        ),
        (Icons.check_circle_outline, 'Bấm Thêm ở góc trên bên phải'),
      ],
      MobilePlatform.android => const [
        (Icons.more_vert_rounded, 'Bấm nút ba chấm ở góc trên bên phải Chrome'),
        (
          Icons.install_mobile_rounded,
          'Chọn "Cài đặt ứng dụng" hoặc "Thêm vào Màn hình chính"',
        ),
        (Icons.check_circle_outline, 'Xác nhận Cài đặt'),
      ],
      MobilePlatform.other => const [
        (
          Icons.menu_rounded,
          'Mở trình đơn của trình duyệt (thường ở góc trên bên phải)',
        ),
        (
          Icons.install_desktop_rounded,
          'Tìm mục "Cài đặt ứng dụng" hoặc "Thêm vào Màn hình chính"',
        ),
      ],
    };

    return [
      for (var index = 0; index < steps.length; index++)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(steps[index].$1, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[index].$2,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
