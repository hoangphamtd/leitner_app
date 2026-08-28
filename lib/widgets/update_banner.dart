import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/web_metrics/web_metrics.dart';

/// Dải thông báo có bản cập nhật, hiện đè lên đỉnh mọi màn hình.
///
/// Lý do tồn tại: người dùng đã cài app vào màn hình chính thì không có thanh
/// địa chỉ, không có nút tải lại, và cũng không có cách nào biết mình đang chạy
/// bản nào. Đã xảy ra thật — người dùng kẹt ở bản cũ suốt nhiều lần triển khai
/// mà không hay biết. Dải này là lối thoát duy nhất cho họ.
class UpdateBanner extends StatefulWidget {
  final Widget child;

  const UpdateBanner({super.key, required this.child});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  static const WebMetrics _web = WebMetrics();

  /// Nhịp hỏi lại xem đã có bản mới chưa.
  ///
  /// Cờ báo nằm bên JavaScript và được bật bất đồng bộ khi service worker cài
  /// xong, nên phải hỏi lại theo nhịp. Ba giây là đủ nhanh để người dùng thấy
  /// ngay trong phiên đang mở, mà cũng đủ thưa để không tốn gì đáng kể.
  static const Duration _nhipKiemTra = Duration(seconds: 3);

  Timer? _timer;
  bool _coBanMoi = false;
  bool _daBoQua = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_nhipKiemTra, (_) {
      if (!mounted || _daBoQua) return;
      final moi = _web.hasUpdate;
      if (moi != _coBanMoi) setState(() => _coBanMoi = moi);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_coBanMoi || _daBoQua) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        // Đặt đè lên trên thay vì chen vào bố cục, để không đẩy toàn bộ giao
        // diện tụt xuống rồi lại nhảy lên khi người dùng đóng dải.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.system_update_rounded,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Có bản cập nhật',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _web.applyUpdate,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(90, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('TẢI LẠI'),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _daBoQua = true),
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Để sau',
                        color: scheme.onTertiaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
