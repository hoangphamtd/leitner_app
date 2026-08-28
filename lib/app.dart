import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

/// Màu chủ đạo của ứng dụng.
const Color seedColor = Color(0xFF2E6F5E);

/// Gốc cây widget.
///
/// Giao diện dùng bảng màu sinh từ [seedColor] cho cả chế độ sáng và tối, theo
/// đúng yêu cầu ở Phần 4. Hiện lấy theo cài đặt hệ thống; việc cho người dùng
/// tự chọn sáng/tối thuộc màn hình Cài đặt ở giai đoạn sau.
class LeitnerApp extends StatelessWidget {
  const LeitnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leitner — Học từ vựng',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
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
