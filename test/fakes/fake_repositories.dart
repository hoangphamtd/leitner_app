import 'package:leitner_app/models/app_settings.dart';
import 'package:leitner_app/models/flashcard.dart';
import 'package:leitner_app/models/session_state.dart';
import 'package:leitner_app/models/study_log.dart';
import 'package:leitner_app/repositories/card_repository.dart';
import 'package:leitner_app/repositories/session_state_repository.dart';
import 'package:leitner_app/repositories/settings_repository.dart';
import 'package:leitner_app/repositories/study_log_repository.dart';
import 'package:leitner_app/utils/date_utils.dart' as du;

/// Kho thẻ giả, giữ dữ liệu trong bộ nhớ.
///
/// Nhờ đã tách interface ở tầng repository nên test giao diện chạy được mà
/// không cần dựng Hive hay IndexedDB. Đây chính là lợi ích thực tế của nguyên
/// tắc "tầng dữ liệu tách biệt hoàn toàn khỏi UI và khỏi cơ chế lưu trữ".
class FakeCardRepository implements CardRepository {
  final Map<String, Flashcard> _store = {};

  /// Các thẻ đã được ghi qua [save], theo đúng thứ tự — để test kiểm chứng
  /// rằng mỗi lượt trả lời đều được lưu ngay.
  final List<Flashcard> saved = [];

  /// Nạp sẵn dữ liệu đầu vào cho một bài test.
  void seed(List<Flashcard> cards) {
    for (final card in cards) {
      _store[card.id] = card;
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<List<Flashcard>> getAll() async => _store.values.toList();

  @override
  Future<Flashcard?> getById(String id) async => _store[id];

  @override
  Future<List<Flashcard>> getDueCards(DateTime day) async {
    final cutoff = du.DateUtils.endOfDay(day);
    return _store.values
        .where((card) => card.isActive && !card.nextReviewDate.isAfter(cutoff))
        .toList();
  }

  @override
  Future<List<Flashcard>> getInactiveCards() async =>
      _store.values.where((card) => !card.isActive).toList();

  @override
  Future<Map<int, int>> countByBox() async {
    final counts = <int, int>{for (var box = 1; box <= 5; box++) box: 0};
    for (final card in _store.values) {
      if (!card.isActive) continue;
      counts.update(card.boxNumber, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  @override
  Future<void> save(Flashcard card) async {
    _store[card.id] = card;
    saved.add(card);
  }

  @override
  Future<void> saveAll(List<Flashcard> cards) async {
    for (final card in cards) {
      _store[card.id] = card;
      saved.add(card);
    }
  }

  @override
  Future<void> delete(String id) async => _store.remove(id);

  @override
  Future<void> clear() async => _store.clear();
}

/// Kho nhật ký giả.
class FakeStudyLogRepository implements StudyLogRepository {
  final List<StudyLog> appended = [];

  void seed(List<StudyLog> logs) => appended.addAll(logs);

  @override
  Future<void> init() async {}

  @override
  Future<void> append(StudyLog log) async => appended.add(log);

  @override
  Future<List<StudyLog>> getAll() async => List.of(appended);

  @override
  Future<List<StudyLog>> getInRange(DateTime from, DateTime to) async =>
      appended
          .where(
            (log) =>
                !log.answeredAt.isBefore(from) && !log.answeredAt.isAfter(to),
          )
          .toList();

  @override
  Future<List<StudyLog>> getByCardId(String cardId) async =>
      appended.where((log) => log.cardId == cardId).toList();

  @override
  Future<void> clear() async => appended.clear();
}

/// Kho cài đặt giả.
class FakeSettingsRepository implements SettingsRepository {
  AppSettings current = const AppSettings();

  @override
  Future<void> init() async {}

  @override
  Future<AppSettings> load() async => current;

  @override
  Future<void> save(AppSettings settings) async => current = settings;
}

/// Kho trạng thái buổi học giả.
class FakeSessionStateRepository implements SessionStateRepository {
  SessionState? current;

  /// Số lần [clear] được gọi, để test kiểm chứng buổi học xong thì trạng thái
  /// có thật sự bị xoá hay không.
  int clearCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<SessionState?> load() async => current;

  @override
  Future<void> save(SessionState state) async => current = state;

  @override
  Future<void> clear() async {
    clearCount++;
    current = null;
  }
}
