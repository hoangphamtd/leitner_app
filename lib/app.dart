import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/main_shell.dart';
import 'services/diagnostics_service.dart';
import 'utils/web_metrics/web_metrics.dart';
import 'widgets/error_banner.dart';
import 'widgets/update_banner.dart';

/// Màu chủ đạo của ứng dụng.
const Color seedColor = Color(0xFF2E6F5E);

/// Gốc cây widget.
///
/// Giao diện dùng bảng màu sinh từ [seedColor] cho cả chế độ sáng và tối, theo
/// đúng yêu cầu ở Phần 4. Chế độ hiển thị lấy từ [SettingsProvider] nên đổi
/// trong màn hình Cài đặt là thấy hiệu lực ngay, không cần khởi động lại.
/// Khoá của lớp ghi nhận chạm ở gốc cây, để chạy lại phép thử chạm từ đúng đó.
final GlobalKey _khoaGocCham = GlobalKey();

/// Số lớp trên cùng của đường chạm được ghi lại.
///
/// Bốn là đủ để nhận ra thứ đang nhận cú chạm mà không làm nhật ký dài dòng.
const int _soLopGhiLai = 4;

/// Xem cú chạm ở [viTri] thật sự rơi vào widget nào.
///
/// Vì sao cần: toạ độ chạm đúng KHÔNG có nghĩa là chạm trúng nút. Đã có lần một
/// hộp lỗi vô hình nằm đè lên cả dải thông báo và nuốt sạch thao tác, mà nhật ký
/// chạm vẫn đẹp vì lớp ghi nhận ở gốc cây là `translucent` — nó ghi nhận kể cả
/// khi không nút nào nhận được. Ghi thêm đường chạm thì lần sau nhìn là biết
/// ngay chạm trúng cái gì, khỏi phải đoán.
///
/// Trả về tên các lớp vẽ trên cùng của đường chạm. Dùng tên lớp chứ không dùng
/// tên widget vì `debugCreator` chỉ có ở bản gỡ rối, còn lỗi thì chỉ xuất hiện
/// ở bản phát hành trên máy thật.
List<String> _doAiNhanCham(Offset viTri) {
  final o = _khoaGocCham.currentContext?.findRenderObject();
  if (o is! RenderBox) return const [];
  final ketQua = BoxHitTestResult();
  o.hitTest(ketQua, position: viTri);
  return [
    for (final muc in ketQua.path.take(_soLopGhiLai))
      muc.target.runtimeType.toString(),
  ];
}

class LeitnerApp extends StatelessWidget {
  const LeitnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (settings) => settings.themeMode,
    );

    // Mở thẳng màn hình chẩn đoán khi địa chỉ kết thúc bằng #debug.
    //
    // Đọc BẢN CHỤP hash lấy lúc mở trang, không đọc `location.hash` hiện tại:
    // Flutter web quản lý địa chỉ bằng hash và ghi đè nó thành '#/' ngay khi
    // khởi động, nên đọc muộn thì '#debug' đã biến mất. Đây đúng là lỗi khiến
    // đường '#debug' không dùng được.
    const web = WebMetrics();
    final moChanDoan = web.initialHash.contains('debug');

    return MaterialApp(
      title: 'Leitner — Học từ vựng',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,
      // Bọc toàn bộ app để ghi lại MỌI lần chạm, kể cả chạm vào chỗ không có
      // nút. Chạm vào nút mà không thấy gì xảy ra chính là triệu chứng cần đo,
      // nên không thể chỉ đo ở những nơi đã có sẵn xử lý.
      builder: (context, child) => Listener(
        key: _khoaGocCham,
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => DiagnosticsService.instance.recordTouch(
          event.position.dx,
          event.position.dy,
          nhanBoi: _doAiNhanCham(event.localPosition),
        ),
        // Hai dải bọc ngoài cùng để hiện được trên MỌI màn hình. Dải đỏ báo lỗi
        // nằm ngoài cùng: khi một màn hình con dựng hỏng, nó vẫn phải hiện được.
        //
        // Overlay.wrap là BẮT BUỘC ở đây, đừng gỡ đi.
        //
        // `MaterialApp.builder` bọc widget ở phía TRÊN Navigator, mà Overlay lại
        // do chính Navigator tạo ra. Mọi widget cần Overlay đặt ở đây —
        // `Tooltip`, `PopupMenuButton`, `DropdownButton` — sẽ ném lỗi:
        //
        //     No Overlay widget found.
        //     RawTooltip widgets require an Overlay widget ancestor
        //
        // Đã xảy ra thật: hai dải dưới đây đều có nút kèm `tooltip`, nên mỗi lần
        // dải hiện là một lần ném lỗi khi dựng. Cách chữa đúng là cấp cho chúng
        // một Overlay, chứ không phải gỡ bỏ `tooltip` — gỡ đi thì chỉ hết triệu
        // chứng, lần sau ai thêm widget cần Overlay vào đây lại vấp đúng bẫy cũ.
        child: Overlay.wrap(
          child: ErrorBanner(
            child: UpdateBanner(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
      home: moChanDoan ? const DiagnosticsScreen() : const MainShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Nút to, bo tròn, đủ chỗ cho ngón tay cái theo yêu cầu Phần 4.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
