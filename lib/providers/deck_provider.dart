import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../repositories/card_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/study_log_repository.dart';
import '../services/leitner_service.dart';
import '../services/stats_service.dart';
import '../utils/logger.dart';

/// Trạng thái nạp dữ liệu của màn hình Tổng quan.
enum DeckStatus { loading, ready, error }

/// Quản lý toàn cảnh bộ thẻ: số thẻ mỗi hộp, thẻ đến hạn, số liệu tổng quan.
///
/// Provider là nơi DUY NHẤT nối giữa giao diện và tầng dữ liệu. Widget chỉ đọc
/// thuộc tính và gọi phương thức ở đây, không bao giờ chạm vào repository hay
/// Hive. Bản thân provider cũng không chứa thuật toán — nó gọi sang
/// [LeitnerService] và [StatsService].
class DeckProvider extends ChangeNotifier {
  final CardRepository cardRepository;
  final StudyLogRepository logRepository;
  final SettingsRepository settingsRepository;
  final LeitnerService leitner;
  final StatsService stats;
  final Logger _log = const Logger('DeckProvider');

  DeckProvider({
    required this.cardRepository,
    required this.logRepository,
    required this.settingsRepository,
    required this.leitner,
    this.stats = const StatsService(),
  });

  DeckStatus _status = DeckStatus.loading;
  DeckStatus get status => _status;

  /// Mô tả lỗi để hiển thị cho người dùng. Null khi không có lỗi.
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<int, int> _countByBox = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  Map<int, int> get countByBox => _countByBox;

  Set<int> _boxesDueToday = const {};
  Set<int> get boxesDueToday => _boxesDueToday;

  int _dueCount = 0;

  /// Số thẻ đến hạn học hôm nay.
  int get dueCount => _dueCount;

  int _masteredCount = 0;

  /// Số từ đã thuộc, tức số thẻ đang ở Hộp 5.
  int get masteredCount => _masteredCount;

  int _streak = 0;

  /// Chuỗi ngày học liên tiếp.
  int get streak => _streak;

  int _libraryCount = 0;

  /// Số thẻ còn nằm trong thư viện, chưa được kích hoạt.
  int get libraryCount => _libraryCount;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  int _remainingQuota = 0;

  /// Số suất kích hoạt từ mới còn lại trong hôm nay.
  int get remainingQuota => _remainingQuota;

  /// Có thể bắt đầu buổi học hay không.
  bool get canStudy => _dueCount > 0;

  /// Đọc lại toàn bộ số liệu từ kho.
  ///
  /// Gọi lúc mở app và sau mỗi lần dữ liệu đổi (học xong, kích hoạt thẻ mới).
  Future<void> refresh({DateTime? now}) async {
    final today = now ?? DateTime.now();
    try {
      final cards = await cardRepository.getAll();
      final dueCards = await cardRepository.getDueCards(today);
      final logs = await logRepository.getAll();
      final settings = await settingsRepository.load();

      _countByBox = await cardRepository.countByBox();
      _boxesDueToday = stats.boxesDueOn(cards, today);
      _dueCount = dueCards.length;
      _masteredCount = stats.countMastered(cards);
      _streak = stats.calculateStreak(logs, today);
      _libraryCount = cards.where((card) => !card.isActive).length;
      _settings = settings;
      _remainingQuota = settings.remainingQuotaOn(today);

      _status = DeckStatus.ready;
      _errorMessage = null;
    } catch (error, stackTrace) {
      // Không nuốt lỗi: ghi lại đầy đủ rồi chuyển sang trạng thái lỗi để giao
      // diện hiển thị, thay vì im lặng đưa ra màn hình trống.
      _log.error('Không đọc được dữ liệu bộ thẻ', error, stackTrace);
      _status = DeckStatus.error;
      _errorMessage = 'Không đọc được dữ liệu. $error';
    }
    notifyListeners();
  }

  /// Lấy danh sách thẻ đến hạn, đã xếp sẵn thành hàng đợi cho buổi học.
  Future<List<Flashcard>> buildTodayQueue({DateTime? now}) async {
    final dueCards = await cardRepository.getDueCards(now ?? DateTime.now());
    return leitner.buildTodayQueue(dueCards);
  }

  /// Kích hoạt thêm thẻ mới từ thư viện vào Hộp 1.
  ///
  /// Trả về số thẻ thật sự được kích hoạt — có thể ít hơn [count] khi đã chạm
  /// hạn mức trong ngày hoặc thư viện không còn đủ thẻ.
  Future<int> activateNewCards({int? count, DateTime? now}) async {
    final moment = now ?? DateTime.now();
    try {
      final library = await cardRepository.getInactiveCards();
      final result = leitner.activateNewCards(
        libraryCards: library,
        settings: await settingsRepository.load(),
        requestedCount: count,
        now: moment,
      );

      if (result.activatedCards.isEmpty) return 0;

      await cardRepository.saveAll(result.activatedCards);
      await settingsRepository.save(result.updatedSettings);
      _log.info('Đã kích hoạt ${result.activatedCards.length} thẻ mới');

      await refresh(now: moment);
      return result.activatedCards.length;
    } catch (error, stackTrace) {
      _log.error('Không kích hoạt được thẻ mới', error, stackTrace);
      _status = DeckStatus.error;
      _errorMessage = 'Không kích hoạt được thẻ mới. $error';
      notifyListeners();
      rethrow;
    }
  }
}
