import 'package:hive_ce/hive.dart';

import '../models/session_state.dart';
import '../utils/logger.dart';
import 'card_repository.dart' show RepositoryException;
import 'session_state_repository.dart';

/// Bản cài đặt [SessionStateRepository] dùng Hive CE.
class HiveSessionStateRepository implements SessionStateRepository {
  static const String boxName = 'session_state';
  static const String _singletonKey = 'current';

  final Logger _log = const Logger('HiveSessionStateRepository');
  Box<SessionState>? _box;

  Box<SessionState> get _requireBox {
    final box = _box;
    if (box == null) {
      throw const RepositoryException(
        'Kho buổi học chưa được khởi tạo, phải gọi init() trước',
      );
    }
    return box;
  }

  @override
  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<SessionState>(boxName);
    } catch (error, stackTrace) {
      _log.error('Không mở được kho buổi học', error, stackTrace);
      throw RepositoryException('Không mở được kho buổi học', error);
    }
  }

  @override
  Future<SessionState?> load() async => _requireBox.get(_singletonKey);

  @override
  Future<void> save(SessionState state) async {
    try {
      await _requireBox.put(_singletonKey, state);
    } catch (error, stackTrace) {
      _log.error('Không lưu được buổi học dở', error, stackTrace);
      throw RepositoryException('Không lưu được buổi học dở', error);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _requireBox.delete(_singletonKey);
    } catch (error, stackTrace) {
      _log.error('Không xoá được buổi học dở', error, stackTrace);
      throw RepositoryException('Không xoá được buổi học dở', error);
    }
  }
}
