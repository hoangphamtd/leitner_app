import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../providers/library_provider.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

/// Khung chính với thanh điều hướng ba mục ở đáy.
///
/// Đặt thanh ở đáy để ngón cái với tới được, đúng yêu cầu "thao tác được bằng
/// một ngón tay" ở Phần 4. Màn hình Học không nằm trong thanh này — nó được mở
/// chồng lên, vì lúc đang học thì không nên có gì mời người ta bỏ đi giữa chừng.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giữ nguyên trạng thái của từng tab — ô tìm kiếm và bộ lọc
      // ở Thư viện không bị xoá mỗi lần người dùng chuyển qua tab khác rồi về.
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), LibraryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onSelect,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Thư viện',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  void _onSelect(int index) {
    setState(() => _index = index);

    // Dữ liệu có thể đã đổi ở tab khác — thêm từ ở Thư viện làm đổi số liệu
    // Tổng quan, và ngược lại kích hoạt từ ở Tổng quan làm đổi danh sách Thư
    // viện. Đọc lại khi chuyển tab là cách rẻ và chắc chắn nhất.
    switch (index) {
      case 0:
        context.read<DeckProvider>().refresh();
      case 1:
        context.read<LibraryProvider>().refresh();
    }
  }
}
