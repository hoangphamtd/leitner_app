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

  /// Ép dải hiện ra, chỉ dùng cho kiểm thử.
  ///
  /// Trạng thái thật nằm bên phía trình duyệt nên trên máy ảo Dart dải không
  /// bao giờ hiện — mà đúng cái dải này lại đang bị nghi chặn thao tác chạm,
  /// nên phải dựng được nó trong test mới kiểm chứng được.
  @visibleForTesting
  final bool? forceVisible;

  const UpdateBanner({super.key, required this.child, this.forceVisible});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  static const WebMetrics _web = WebMetrics();

  bool _coBanMoi = false;
  bool _daBoQua = false;

  @override
  void initState() {
    super.initState();
    // Kiểm tra đúng ba thời điểm có nghĩa, thay cho việc hỏi lại mỗi ba giây:
    //   * lúc mở app,
    //   * khi phía trình duyệt báo sang có bản mới,
    //   * khi app quay lại từ nền (người dùng để đó rồi mở lại sau vài ngày).
    // Hỏi theo nhịp là lãng phí thấy rõ: cứ đúng chu kỳ lại đánh thức luồng
    // chính dù chẳng có việc gì.
    WidgetsBinding.instance.addObserver(this);
    _kiemTra();
    _web.onUpdateAvailable(_kiemTra);
  }

  void _kiemTra() {
    if (!mounted || _daBoQua) return;
    final moi = _web.hasUpdate;
    if (moi != _coBanMoi) setState(() => _coBanMoi = moi);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _kiemTra();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hien = widget.forceVisible ?? _coBanMoi;
    if (!hien || _daBoQua) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    // Xếp dải NẰM TRÊN nội dung theo chiều dọc, không đè lên nó.
    //
    // Bản trước đặt đè bằng Stack/Positioned để tránh giao diện nhảy. Cái giá
    // phải trả quá đắt: dải phủ kín thanh tiêu đề, tiêu đề "Leitner" biến mất
    // và nút Chẩn đoán ngay cạnh cũng không bấm được nữa. Người dùng đã báo
    // đúng triệu chứng này. Một lần dịch xuống khi có bản cập nhật thì chấp
    // nhận được, còn che mất nút thì không.
    return Column(
      children: [
        Material(
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
        // Dải đã chiếm phần lề an toàn phía trên rồi, nên phải gỡ lề đó khỏi
        // MediaQuery của phần còn lại — không thì màn hình con chừa thêm một
        // lần nữa và thừa ra một khoảng trống.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
