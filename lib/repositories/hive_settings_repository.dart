import 'package:hive_ce/hive.dart';

import '../models/app_settings.dart';
import '../utils/logger.dart';
import 'card_repository.dart' show RepositoryException;
import 'settings_repository.dart';

/// Bản cài đặt [SettingsRepository] dùng Hive CE.
///
/// Chỉ có đúng một bản ghi cài đặt, nên dùng một khoá cố định thay vì id động.
class HiveSettingsRepository implements SettingsRepository {
  static const String boxName = 'app_settings';
  static const String _singletonKey = 'current';

  final Logger _log = const Logger('HiveSettingsRepository');
  Box<AppSettings>? _box;

  Box<AppSettings> get _requireBox {
    final box = _box;
    if (box == null) {
      throw const RepositoryException(
        'Kho cài đặt chưa được khởi tạo, phải gọi init() trước',
      );
    }
    return box;
  }

  @override
  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<AppSettings>(boxName);
    } catch (error, stackTrace) {
      _log.error('Không mở được kho cài đặt', error, stackTrace);
      throw RepositoryException('Không mở được kho cài đặt', error);
    }
  }

  /// Lần đầu chạy thì chưa có bản ghi nào, trả về mặc định chứ không ném lỗi.
  @override
  Future<AppSettings> load() async =>
      _requireBox.get(_singletonKey) ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) async {
    try {
      await _requireBox.put(_singletonKey, settings);
    } catch (error, stackTrace) {
      _log.error('Không ghi được cài đặt', error, stackTrace);
      throw RepositoryException('Không ghi được cài đặt', error);
    }
  }
}
