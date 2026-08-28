import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/flashcard.dart';
import '../models/session_state.dart';
import '../repositories/card_repository.dart';
import '../repositories/session_state_repository.dart';
import '../repositories/study_log_repository.dart';
import '../services/leitner_service.dart';
import '../services/study_session.dart';
import '../utils/logger.dart';

/// Trạng thái của màn hình Học.
enum StudyStatus {
  /// Chưa bắt đầu buổi nào.
  idle,

  /// Đang nạp hàng đợi.
  loading,

  /// Đang học, còn thẻ trong hàng đợi.
  studying,

  /// Hàng đợi đã rỗng, hiện màn hình chúc mừng.
  finished,

  error,
}

/// Điều khiển một buổi học.
///
/// Provider giữ [StudySession] — cấu trúc hàng đợi sống trong bộ nhớ — và lo
/// việc ghi kết quả từng lượt trả lời xuống kho. Toàn bộ luật nghiệp vụ nằm ở
/// [LeitnerService] và [StudySession], ở đây chỉ là khâu nối.
class StudyProvider extends ChangeNotifier {
  final CardRepository cardRepository;
  final StudyLogRepository logRepository;
  final SessionStateRepository sessionStateRepository;
  final LeitnerService leitner;
  final Uuid uuid;
  final Logger _log = const Logger('StudyProvider');

  StudyProvider({
    required this.cardRepository,
    required this.logRepository,
    required this.sessionStateRepository,
    required this.leitner,
    this.uuid = const Uuid(),
  });

  StudyStatus _status = StudyStatus.idle;
  StudyStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StudySession? _session;

  /// Tổng số thẻ lúc bắt đầu buổi, dùng để vẽ thanh tiến độ.
  int _initialCount = 0;
  int get initialCount => _initialCount;

  /// Thẻ đang hiển thị. Null khi buổi học đã xong hoặc chưa bắt đầu.
  Flashcard? get currentCard => _session?.currentCard;

  /// Số thẻ còn lại trong hàng đợi.
  int get remainingCount => _session?.remainingCount ?? 0;

  /// Số liệu tổng kết buổi học.
  SessionStats? get stats => _session?.stats;

  /// Mặt sau của thẻ đã được lật ra chưa.
  ///
  /// Giữ ở provider chứ không giữ trong widget, để khi chuyển sang thẻ kế tiếp
  /// thì trạng thái lật chắc chắn được đặt lại — nếu để trong widget thì thẻ mới
  /// dễ hiện ngay mặt sau do widget được tái sử dụng.
  bool _isRevealed = false;
  bool get isRevealed => _isRevealed;

  /// Tiến độ buổi học, từ 0 đến 1, dùng cho thanh tiến độ.
  ///
  /// Tính theo số thẻ đã rời hàng đợi so với số thẻ ban đầu. Thẻ trả lời sai
  /// quay lại hàng đợi nên tiến độ có thể đứng yên — đó là đúng ý: người học
  /// chưa thật sự tiến thêm được bước nào.
  double get progress {
    if (_initialCount == 0) return 0;
    final done = _session?.stats.cardsCompleted ?? 0;
    return (done / _initialCount).clamp(0.0, 1.0);
  }

  /// Bắt đầu một buổi học mới với hàng đợi đã dựng sẵn.
  ///
  /// Ghi đè lên buổi dở cũ nếu có — người học đã chọn học lại từ đầu.
  Future<void> start(List<Flashcard> queue, {DateTime? now}) async {
    if (queue.isEmpty) {
      _status = StudyStatus.finished;
      _session = null;
      _initialCount = 0;
      await _clearSavedState();
      notifyListeners();
      return;
    }

    _session = StudySession(
      queue: queue,
      service: leitner,
      logIdFactory: () => uuid.v4(),
      startedAt: now ?? DateTime.now(),
    );
    _initialCount = queue.length;
    _isRevealed = false;
    _status = StudyStatus.studying;
    _errorMessage = null;
    await _persistState();
    notifyListeners();
  }

  /// Dựng lại buổi học dở từ ảnh chụp đã lưu.
  ///
  /// [state] là ảnh chụp, [cardsById] là các thẻ đã đọc sẵn từ kho. Thẻ nào
  /// trong hàng đợi mà không còn trong kho — người học đã xoá nó ở màn hình Thư
  /// viện giữa chừng — thì bị bỏ qua thay vì làm hỏng cả buổi.
  Future<void> restore(
    SessionState state,
    Map<String, Flashcard> cardsById,
  ) async {
    final queue = <Flashcard>[];
    for (final id in state.queueCardIds) {
      final card = cardsById[id];
      if (card != null) queue.add(card);
    }

    if (queue.isEmpty) {
      _log.warning('Buổi dở không còn thẻ nào hợp lệ, bỏ qua');
      await _clearSavedState();
      reset();
      return;
    }

    _session = StudySession.restore(
      queue: queue,
      state: state,
      service: leitner,
      logIdFactory: () => uuid.v4(),
    );
    _initialCount = state.initialCount;
    _isRevealed = false;
    _status = StudyStatus.studying;
    _errorMessage = null;
    _log.info('Đã khôi phục buổi học dở, còn ${queue.length} thẻ');
    notifyListeners();
  }

  /// Lật thẻ để xem mặt sau.
  void reveal() {
    if (_isRevealed) return;
    _isRevealed = true;
    notifyListeners();
  }

  /// Trả lời thẻ đang hiển thị.
  ///
  /// Ghi thẻ và nhật ký xuống kho ngay trong lượt, không gom lại tới cuối buổi.
  /// Người học có thể đóng trình duyệt bất cứ lúc nào, nên mỗi lượt phải được
  /// lưu ngay thì tiến độ mới an toàn.
  Future<void> answer(bool isCorrect, {DateTime? now}) async {
    final session = _session;
    if (session == null || session.isFinished) return;

    try {
      final outcome = session.answer(isCorrect, now: now);
      await cardRepository.save(outcome.updatedCard);
      await logRepository.append(outcome.log);

      _isRevealed = false;
      if (session.isFinished) {
        _status = StudyStatus.finished;
        // Buổi đã xong thì ảnh chụp không còn ý nghĩa, xoá đi để lần mở app sau
        // không hỏi "tiếp tục buổi dở?" một cách vô duyên.
        await _clearSavedState();
        _log.info(
          'Buổi học kết thúc: ${session.stats.totalAnswers} lượt trả lời',
        );
      } else {
        // Lưu lại sau MỖI lượt, không đợi tới cuối buổi. Người học có thể bị
        // ngắt bất cứ lúc nào.
        await _persistState();
      }
    } catch (error, stackTrace) {
      _log.error('Không ghi được kết quả lượt trả lời', error, stackTrace);
      _status = StudyStatus.error;
      _errorMessage = 'Không lưu được kết quả. $error';
    }
    notifyListeners();
  }

  /// Ghi ảnh chụp buổi học xuống kho.
  ///
  /// Lỗi ở đây chỉ ghi nhật ký chứ không làm hỏng buổi học đang diễn ra: mất
  /// khả năng khôi phục thì khó chịu, nhưng chặn người học giữa chừng còn tệ hơn.
  Future<void> _persistState() async {
    final session = _session;
    if (session == null) return;
    try {
      await sessionStateRepository.save(
        session.toState(initialCount: _initialCount),
      );
    } catch (error, stackTrace) {
      _log.error('Không lưu được trạng thái buổi học', error, stackTrace);
    }
  }

  Future<void> _clearSavedState() async {
    try {
      await sessionStateRepository.clear();
    } catch (error, stackTrace) {
      _log.error('Không xoá được trạng thái buổi học', error, stackTrace);
    }
  }

  /// Bỏ buổi dở đã lưu, dùng khi người học chọn học lại từ đầu.
  Future<void> discardSavedSession() async {
    await _clearSavedState();
    reset();
  }

  /// Dọn buổi học, đưa provider về trạng thái ban đầu.
  ///
  /// KHÔNG xoá ảnh chụp dưới kho: người học thoát giữa chừng thì buổi dở phải
  /// còn nguyên để lần sau tiếp tục được.
  void reset() {
    _session = null;
    _initialCount = 0;
    _isRevealed = false;
    _status = StudyStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
