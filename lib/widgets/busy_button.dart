import 'package:flutter/material.dart';

/// Nút tự thay nhãn bằng vòng quay chờ khi đang xử lý.
///
/// Có widget này vì bài học rút ra từ một lỗi thật: nút không có chỉ báo nào thì
/// trên máy chậm người dùng bấm mà không thấy gì xảy ra, tưởng hỏng nên bấm
/// tiếp — mỗi lần bấm lại chạy thêm một lượt ghi dữ liệu, càng bấm càng chậm.
///
/// Khi [isBusy] bật, nút vừa bị vô hiệu hoá vừa hiện vòng quay, nên người dùng
/// biết máy đang làm việc chứ không phải nút hỏng.
class BusyButton extends StatelessWidget {
  final bool isBusy;
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  /// true thì dùng nút nền đặc, false thì dùng nút viền.
  final bool filled;

  final ButtonStyle? style;

  const BusyButton({
    super.key,
    required this.isBusy,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.filled = true,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    // Vòng quay được bọc trong khung cùng kích thước với biểu tượng, để nút
    // không nhảy kích thước lúc chuyển trạng thái.
    final leading = isBusy
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        : Icon(icon, size: 22);

    final effectiveOnPressed = isBusy ? null : onPressed;
    final text = Text(isBusy ? 'Đang xử lý…' : label);

    return filled
        ? FilledButton.icon(
            onPressed: effectiveOnPressed,
            style: style,
            icon: leading,
            label: text,
          )
        : OutlinedButton.icon(
            onPressed: effectiveOnPressed,
            style: style,
            icon: leading,
            label: text,
          );
  }
}
