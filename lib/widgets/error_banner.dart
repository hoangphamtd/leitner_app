import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/diagnostics_service.dart';
import '../utils/web_metrics/web_metrics.dart';

/// Dải đỏ báo lỗi, hiện đè lên đỉnh mọi màn hình.
///
/// Lý do tồn tại: ở chế độ đã cài vào màn hình chính, người dùng KHÔNG mở được
/// công cụ nhà phát triển, không thấy console, và cũng không có thanh địa chỉ để
/// đi tới màn hình khác. Nếu một màn hình nào đó hỏng thì họ chỉ thấy nó không
/// mở ra, không biết vì sao.
///
/// Dải này cố ý bọc ở GỐC cây widget, ngay dưới [MaterialApp], nên nó hiện được
/// kể cả khi một màn hình con dựng lỗi hoặc điều hướng không đi tới đâu.
class ErrorBanner extends StatefulWidget {
  final Widget child;

  /// Ép dải hiện ra với số lỗi cho trước, chỉ dùng cho kiểm thử.
  @visibleForTesting
  final int? forceErrorCount;

  const ErrorBanner({super.key, required this.child, this.forceErrorCount});

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> with WidgetsBindingObserver {
  static const WebMetrics _web = WebMetrics();

  int _soLoi = 0;
  bool _moRong = false;
  bool _daDong = false;

  @override
  void initState() {
    super.initState();
    // Được BÁO khi có lỗi mới, thay vì cứ hai giây lại hỏi một lần. Lỗi Dart
    // thì nghe thẳng từ bộ thu thập, lỗi JavaScript thì phía trình duyệt gọi
    // ngược sang. Cách này chỉ chạy đúng lúc có việc.
    WidgetsBinding.instance.addObserver(this);
    _demLai();
    _web.onJsError(_demLai);
    DiagnosticsService.instance.addListener(_demLai);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lỗi có thể đã được ghi trong lúc app nằm ở nền.
    if (state == AppLifecycleState.resumed) _demLai();
  }

  void _demLai() {
    if (!mounted) return;
    final tong =
        _web.jsErrors.length +
        _web.previousSessionErrors.length +
        DiagnosticsService.instance.dartErrors.length;
    if (tong != _soLoi) setState(() => _soLoi = tong);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DiagnosticsService.instance.removeListener(_demLai);
    super.dispose();
  }

  /// Gom mọi lỗi thành một khối chữ để người dùng chép gửi đi.
  String _gomThanhChu() {
    final buffer = StringBuffer()
      ..writeln('=== LEITNER — NHẬT KÝ LỖI ===')
      ..writeln('Bản: ${_web.buildVersion}')
      ..writeln('Chế độ mở: ${_web.displayMode}')
      ..writeln('Trình duyệt: ${_web.userAgent}')
      ..writeln('');

    if (_web.previousSessionErrors.isNotEmpty) {
      buffer.writeln('--- Lỗi các phiên trước ---');
      for (final e in _web.previousSessionErrors) {
        buffer.writeln('[${e.luc} ms] ${e.nguon}: ${e.thongDiep}');
        if (e.chiTiet != null) buffer.writeln('   ${e.chiTiet}');
      }
      buffer.writeln('');
    }
    if (_web.jsErrors.isNotEmpty) {
      buffer.writeln('--- Lỗi JavaScript phiên này ---');
      for (final e in _web.jsErrors) {
        buffer.writeln('[${e.luc} ms] ${e.nguon}: ${e.thongDiep}');
        if (e.chiTiet != null) buffer.writeln('   ${e.chiTiet}');
      }
      buffer.writeln('');
    }
    final dart = DiagnosticsService.instance.dartErrors;
    if (dart.isNotEmpty) {
      buffer.writeln('--- Lỗi Dart phiên này ---');
      for (final e in dart) {
        buffer.writeln('[${e.atMs} ms] ${e.message}');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final soLoi = widget.forceErrorCount ?? _soLoi;
    if (soLoi == 0 || _daDong) return widget.child;

    // Xếp dải NẰM TRÊN nội dung theo chiều dọc, không đè lên nó — cùng lý do
    // như dải cập nhật: đè lên thì che mất thanh tiêu đề và nút trên đó.
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFB3261E),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _moRong = !_moRong),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$soLoi lỗi — chạm để xem',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              _moRong ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white,
                            ),
                            IconButton(
                              onPressed: () => setState(() => _daDong = true),
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.white,
                              tooltip: 'Ẩn dải này',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_moRong)
                      _ChiTietLoi(
                        noiDung: _gomThanhChu(),
                        onCopy: _chep,
                        onXoa: _xoa,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Gỡ lề an toàn phía trên khỏi phần còn lại, vì dải đã chiếm chỗ đó.
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

  Future<void> _chep() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: _gomThanhChu()));
    messenger?.showSnackBar(
      const SnackBar(content: Text('Đã chép nhật ký lỗi')),
    );
  }

  void _xoa() {
    _web.clearErrors();
    setState(() {
      _soLoi = 0;
      _moRong = false;
    });
  }
}

class _ChiTietLoi extends StatelessWidget {
  final String noiDung;
  final VoidCallback onCopy;
  final VoidCallback onXoa;

  const _ChiTietLoi({
    required this.noiDung,
    required this.onCopy,
    required this.onXoa,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giới hạn chiều cao rồi cho cuộn: nhật ký dài không được phép nuốt
          // trọn màn hình khiến người dùng không dùng app được nữa.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                noiDung,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCopy,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB3261E),
                    minimumSize: const Size.fromHeight(44),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('CHÉP'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onXoa,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size(80, 44),
                ),
                child: const Text('XOÁ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
