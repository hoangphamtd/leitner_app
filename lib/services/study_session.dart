import 'dart:collection';

import '../models/flashcard.dart';
import '../models/study_log.dart';
import 'leitner_service.dart';

/// Số liệu tổng kết một buổi học, dùng cho màn hình chúc mừng.
class SessionStats {
  /// Số lượt bấm nút, tính cả những lượt gặp lại thẻ đã sai.
  final int totalAnswers;

  /// Số lượt trả lời đúng.
  final int correctAnswers;

  /// Số lượt trả lời sai.
  final int wrongAnswers;

  /// Số thẻ khác nhau đã học xong trong buổi.
  final int cardsCompleted;

  /// Số thẻ từng trả lời sai ít nhất một lần trong buổi.
  final int cardsLapsed;

  const SessionStats({
    required this.totalAnswers,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.cardsCompleted,
    required this.cardsLapsed,
  });

  /// Tỉ lệ đúng trên tổng số lượt, tính theo phần trăm. Chưa trả lời lượt nào
  /// thì trả về 0 thay vì chia cho 0.
  double get accuracyPercent =>
      totalAnswers == 0 ? 0 : correctAnswers * 100 / totalAnswers;
}

/// Hàng đợi của một buổi học.
///
/// Đây là cấu trúc SỐNG TRONG BỘ NHỚ, tách hẳn khỏi `boxNumber` lưu dưới kho dữ
/// liệu. Lý do phải tách: khi người học trả lời sai, thẻ lập tức rơi về Hộp 1 và
/// được hẹn ôn lại ngày mai — nhưng nó vẫn phải xuất hiện thêm lần nữa NGAY
/// TRONG BUỔI NÀY. Nếu chỉ dựa vào hộp và ngày đến hạn dưới kho thì không thể
/// diễn tả được yêu cầu đó.
///
/// Buổi học chỉ kết thúc khi hàng đợi rỗng, chứ không phải khi đi hết lượt đầu.
class StudySession {
  /// Thuật toán Leitner dùng để tính hộp và lịch ôn cho từng lượt trả lời.
  final LeitnerService service;

  /// Hàng đợi thẻ chờ trả lời. Thẻ sai được đẩy xuống cuối hàng này.
  final Queue<Flashcard> _queue;

  /// Mã các thẻ đã trả lời sai ít nhất một lần trong buổi.
  ///
  /// Ghi nhớ suốt buổi chứ không xoá sau khi người học sửa được, vì luật ở mục
  /// 3.4 quy định thẻ đã sai thì lượt đúng sau đó không được tính là lên hộp.
  final Set<String> _failedCardIds = <String>{};

  /// Mã các thẻ đã rời hàng đợi, dùng để đếm số thẻ học xong.
  final Set<String> _completedCardIds = <String>{};

  /// Nhật ký sinh ra trong buổi, theo đúng thứ tự trả lời.
  final List<StudyLog> _logs = <StudyLog>[];

  /// Sinh mã cho mỗi dòng nhật ký.
  ///
  /// Tiêm từ ngoài vào thay vì gọi thẳng `Uuid()` bên trong, để unit test khoá
  /// được mã và so sánh kết quả một cách tất định.
  final String Function() logIdFactory;

  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  StudySession({
    required List<Flashcard> queue,
    required this.service,
    required this.logIdFactory,
  }) : _queue = Queue<Flashcard>.of(queue);

  /// Thẻ đang hiển thị. Null nghĩa là buổi học đã xong.
  Flashcard? get currentCard => _queue.isEmpty ? null : _queue.first;

  /// Số thẻ còn phải trả lời, kể cả thẻ đã sai đang chờ gặp lại.
  int get remainingCount => _queue.length;

  bool get isFinished => _queue.isEmpty;

  /// Nhật ký của buổi, chỉ đọc.
  List<StudyLog> get logs => List.unmodifiable(_logs);

  SessionStats get stats => SessionStats(
        totalAnswers: _correctAnswers + _wrongAnswers,
        correctAnswers: _correctAnswers,
        wrongAnswers: _wrongAnswers,
        cardsCompleted: _completedCardIds.length,
        cardsLapsed: _failedCardIds.length,
      );

  /// Trả lời thẻ đang hiển thị.
  ///
  /// Trả về [AnswerOutcome] để tầng trên ghi thẻ và nhật ký xuống kho. Bản thân
  /// hàm này chỉ lo phần hàng đợi trong bộ nhớ.
  ///
  /// Ném [StateError] nếu gọi khi hàng đợi đã rỗng — đó là lỗi lập trình ở tầng
  /// trên, không phải tình huống bình thường, nên không được nuốt đi.
  AnswerOutcome answer(bool isCorrect, {DateTime? now}) {
    if (_queue.isEmpty) {
      throw StateError('Hàng đợi đã rỗng, không còn thẻ nào để trả lời');
    }

    final card = _queue.removeFirst();
    final alreadyFailed = _failedCardIds.contains(card.id);

    final outcome = service.applyAnswer(
      card: card,
      isCorrect: isCorrect,
      alreadyFailedThisSession: alreadyFailed,
      logId: logIdFactory(),
      now: now,
    );

    if (isCorrect) {
      _correctAnswers++;
    } else {
      _wrongAnswers++;
      _failedCardIds.add(card.id);
    }

    _logs.add(outcome.log);

    if (outcome.shouldRequeue) {
      // Đẩy về CUỐI hàng đợi, mang theo bản thẻ đã cập nhật. Phải dùng bản mới
      // chứ không phải bản cũ, để lượt gặp lại ghi đúng hộp trước là 1.
      _queue.addLast(outcome.updatedCard);
    } else {
      _completedCardIds.add(card.id);
    }

    return outcome;
  }
}
