import 'package:hive_ce/hive.dart';

import '../models/study_log.dart';
import '../utils/logger.dart';
import 'card_repository.dart' show RepositoryException;
import 'study_log_repository.dart';

/// Bản cài đặt [StudyLogRepository] dùng Hive CE.
class HiveStudyLogRepository implements StudyLogRepository {
  static const String boxName = 'study_logs';

  final Logger _log = const Logger('HiveStudyLogRepository');
  Box<StudyLog>? _box;

  Box<StudyLog> get _requireBox {
    final box = _box;
    if (box == null) {
      throw const RepositoryException(
        'Kho nhật ký chưa được khởi tạo, phải gọi init() trước',
      );
    }
    return box;
  }

  @override
  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = await Hive.openBox<StudyLog>(boxName);
      _log.info('Đã mở kho nhật ký, hiện có ${_box!.length} dòng');
    } catch (error, stackTrace) {
      _log.error('Không mở được kho nhật ký', error, stackTrace);
      throw RepositoryException('Không mở được kho nhật ký', error);
    }
  }

  @override
  Future<void> append(StudyLog log) async {
    try {
      await _requireBox.put(log.id, log);
    } catch (error, stackTrace) {
      _log.error('Không ghi được nhật ký ${log.id}', error, stackTrace);
      throw RepositoryException('Không ghi được nhật ký', error);
    }
  }

  @override
  Future<List<StudyLog>> getAll() async => _requireBox.values.toList();

  @override
  Future<List<StudyLog>> getInRange(DateTime from, DateTime to) async {
    // Lấy trọn hai đầu mút để phía gọi không phải cộng trừ mili giây.
    return _requireBox.values
        .where(
          (log) =>
              !log.answeredAt.isBefore(from) && !log.answeredAt.isAfter(to),
        )
        .toList();
  }

  @override
  Future<List<StudyLog>> getByCardId(String cardId) async =>
      _requireBox.values.where((log) => log.cardId == cardId).toList();

  @override
  Future<void> clear() async {
    try {
      final removed = await _requireBox.clear();
      _log.warning('Đã xoá sạch nhật ký ($removed dòng)');
    } catch (error, stackTrace) {
      _log.error('Không xoá được nhật ký', error, stackTrace);
      throw RepositoryException('Không xoá được nhật ký', error);
    }
  }
}
