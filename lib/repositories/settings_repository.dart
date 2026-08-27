import '../models/app_settings.dart';

/// Cổng đọc ghi cài đặt ứng dụng.
abstract class SettingsRepository {
  Future<void> init();

  /// Cài đặt hiện tại. Lần đầu chạy thì trả về giá trị mặc định.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
