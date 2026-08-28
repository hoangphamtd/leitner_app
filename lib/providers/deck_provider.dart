import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../models/session_state.dart';
import '../repositories/card_repository.dart';
import '../repositories/session_state_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/study_log_repository.dart';
import '../utils/date_utils.dart' as du;
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
  final SessionStateRepository sessionStateRepository;
  final LeitnerService leitner;
  final StatsService stats;
  final Logger _log = const Logger('DeckProvider');

  DeckProvider({
    required this.cardRepository,
    required this.logRepository,
    required this.settingsRepository,
    required this.sessionStateRepository,
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

  bool _busy = false;

  /// Đang chạy một thao tác ghi dữ liệu.
  ///
  /// Giao diện PHẢI vô hiệu hoá nút và hiện vòng quay chờ khi cờ này bật. Không
  /// có nó, người dùng trên máy chậm thấy nút bấm mà không có gì xảy ra, tưởng
  /// hỏng nên bấm tiếp — mỗi lần bấm lại chạy thêm một lượt ghi và đọc lại toàn
  /// bộ kho, càng bấm càng chậm.
  bool get isBusy => _busy;

  void _setBusy(bool value) {
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  SessionState? _resumableSession;

  /// Buổi học dở của HÔM NAY, còn thẻ để học tiếp. Null nếu không có.
  ///
  /// Buổi dở từ ngày trước đã bị [refresh] tự xoá, nên thuộc tính này chỉ bao
  /// giờ trả về buổi của đúng ngày hôm nay.
  SessionState? get resumableSession => _resumableSession;

  bool get hasResumableSession => _resumableSession != null;

  /// Đọc buổi học dở, đồng thời dọn buổi đã cũ.
  ///
  /// Buổi dở chỉ có ý nghĩa trong đúng ngày nó bắt đầu: sang hôm sau, các thẻ đã
  /// trả lời sai đều đã được hẹn lại và danh sách đến hạn cũng khác đi, nên tiếp
  /// tục một hàng đợi cũ sẽ cho người học ôn sai lịch. Vì vậy buổi của ngày
  /// trước bị xoá thẳng, không hỏi han gì.
  Future<SessionState?> _loadResumableSession(DateTime today) async {
    final saved = await sessionStateRepository.load();
    if (saved == null) return null;

    if (!du.DateUtils.isSameDay(saved.startedAt, today)) {
      _log.info('Xoá buổi học dở từ ngày trước');
      await sessionStateRepository.clear();
      return null;
    }
    // Hàng đợi rỗng nghĩa là buổi đã xong mà ảnh chụp còn sót lại.
    if (!saved.hasWork) {
      await sessionStateRepository.clear();
      return null;
    }
    return saved;
  }

  /// Bỏ buổi học dở đang lưu.
  Future<void> discardResumableSession({DateTime? now}) async {
    await sessionStateRepository.clear();
    _resumableSession = null;
    await refresh(now: now);
  }

  /// Tra các thẻ trong hàng đợi của buổi dở, theo mã.
  ///
  /// Trả về map để [StudyProvider.restore] dựng lại hàng đợi đúng thứ tự mà
  /// không phải chạm vào repository.
  Future<Map<String, Flashcard>> loadCardsById(Iterable<String> ids) async {
    final wanted = ids.toSet();
    final cards = await cardRepository.getAll();
    return {
      for (final card in cards)
        if (wanted.contains(card.id)) card.id: card,
    };
  }

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
      _resumableSession = await _loadResumableSession(today);

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

  /// Kích hoạt đúng những thẻ người dùng đã chọn ở màn hình Thư viện.
  ///
  /// Khác [activateNewCards] ở chỗ danh sách thẻ do người dùng chỉ định chứ
  /// không lấy tuần tự từ đầu thư viện. Hạn mức mỗi ngày vẫn được áp dụng y
  /// nguyên, nên chọn nhiều hơn suất còn lại thì phần dư bị cắt.
  ///
  /// Trả về các thẻ THẬT SỰ được kích hoạt, để tầng gọi ghi xuống kho và biết
  /// có bao nhiêu thẻ bị cắt.
  Future<List<Flashcard>> activateSpecificCards(
    List<Flashcard> chosen, {
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    if (_busy) return const [];
    _setBusy(true);
    try {
      final result = leitner.activateNewCards(
        libraryCards: chosen,
        settings: await settingsRepository.load(),
        now: moment,
      );
      if (result.activatedCards.isEmpty) return const [];

      await cardRepository.saveAll(result.activatedCards);
      await settingsRepository.save(result.updatedSettings);
      await refresh(now: moment);
      return result.activatedCards;
    } catch (error, stackTrace) {
      _log.error('Không kích hoạt được thẻ đã chọn', error, stackTrace);
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Kích hoạt thêm thẻ mới từ thư viện vào Hộp 1.
  ///
  /// Trả về số thẻ thật sự được kích hoạt — có thể ít hơn [count] khi đã chạm
  /// hạn mức trong ngày hoặc thư viện không còn đủ thẻ.
  Future<int> activateNewCards({int? count, DateTime? now}) async {
    final moment = now ?? DateTime.now();
    // Chặn bấm chồng: lượt trước chưa xong thì bỏ qua lượt sau, thay vì xếp
    // hàng chạy tiếp và làm máy chậm càng thêm chậm.
    if (_busy) return 0;
    _setBusy(true);
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
    } finally {
      _setBusy(false);
    }
  }
}
