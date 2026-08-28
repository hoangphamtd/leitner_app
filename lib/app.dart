import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/main_shell.dart';
import 'services/diagnostics_service.dart';
import 'utils/web_metrics/web_metrics.dart';

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

    // Mở thẳng màn hình chẩn đoán khi địa chỉ kết thúc bằng #debug. Có đường
    // này để gửi được một cái link đo đạc cho người dùng ở xa, không phải hướng
    // dẫn họ bấm qua ba lớp menu.
    const web = WebMetrics();
    final moChanDoan = web.locationHash.contains('debug');

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
        child: child ?? const SizedBox.shrink(),
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
