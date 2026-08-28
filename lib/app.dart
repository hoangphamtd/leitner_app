import 'package:flutter/material.dart';
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
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => DiagnosticsService.instance.recordTouch(
          event.position.dx,
          event.position.dy,
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
