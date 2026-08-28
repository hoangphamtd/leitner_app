import 'dart:math';

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../models/study_log.dart';
import '../utils/date_utils.dart' as du;

/// Lịch ôn cố định của một hộp Leitner.
///
/// Khác với Leitner cổ điển (cộng thêm N ngày rồi thôi), dự án này gắn mỗi hộp
/// vào một khung thời gian cố định trong tuần hoặc trong tháng. Vì vậy mỗi hộp
/// cần hai thông tin: hôm đó có phải ngày ôn của hộp không, và tối thiểu phải
/// cách lần ôn trước bao lâu.
class BoxSchedule {
  /// Số ngày tối thiểu phải chờ trước khi thẻ được đến hạn lại.
  ///
  /// Có ràng buộc này để tránh cảnh thẻ vừa lên hộp hôm nay thì ngay mai đã đến
  /// hạn. Ví dụ thẻ lên Hộp 2 vào Thứ Hai: không có khoảng cách tối thiểu thì
  /// Thứ Tư đã phải ôn lại, quá dày.
  final int minimumGapDays;

  /// Ngày [date] có thuộc lịch ôn của hộp này không.
  ///
  /// Nhận thêm `cardId` vì riêng Hộp 4 chia đôi kho thẻ theo mã thẻ (mục 3.2).
  final bool Function(DateTime date, String cardId) matches;

  const BoxSchedule({required this.minimumGapDays, required this.matches});
}

/// Kết quả của một lượt trả lời.
///
/// Gói cả ba thứ mà tầng trên cần: thẻ sau khi cập nhật, dòng nhật ký phải ghi,
/// và việc thẻ có phải quay lại hàng đợi hay không.
class AnswerOutcome {
  /// Thẻ đã cập nhật hộp, lịch ôn và các bộ đếm.
  final Flashcard updatedCard;

  /// Dòng nhật ký của lượt trả lời này. Tầng trên có trách nhiệm ghi xuống kho.
  final StudyLog log;

  /// true nghĩa là thẻ phải quay về cuối hàng đợi để gặp lại ngay trong buổi.
  final bool shouldRequeue;

  const AnswerOutcome({
    required this.updatedCard,
    required this.log,
    required this.shouldRequeue,
  });
}

/// Kết quả của một lượt kích hoạt thẻ mới từ thư viện.
class ActivationResult {
  /// Các thẻ vừa được đưa vào Hộp 1.
  final List<Flashcard> activatedCards;

  /// Cài đặt đã cập nhật bộ đếm hạn mức trong ngày.
  final AppSettings updatedSettings;

  /// Số suất còn lại sau lượt kích hoạt này.
  final int remainingQuota;

  const ActivationResult({
    required this.activatedCards,
    required this.updatedSettings,
    required this.remainingQuota,
  });
}

/// Toàn bộ thuật toán lịch ôn tập của Phần 3 trong SOP.
///
/// Lớp này cố ý KHÔNG chạm vào kho dữ liệu và KHÔNG biết gì về giao diện: mọi
/// hàm đều nhận vào dữ liệu và trả ra dữ liệu. Nhờ vậy nó kiểm thử được bằng
/// unit test thuần, không cần dựng Hive hay Flutter.
///
/// Đối chiếu tên hàm với SOP (SOP viết chữ ký bằng tiếng Việt, còn Phần 9 quy
/// định tên hàm phải là tiếng Anh — ở đây theo Phần 9):
///   * `tinhNgayOnKeTiep`       tương ứng [calculateNextReviewDate]
///   * `capNhatTheSauKhiTraLoi` tương ứng [applyAnswer]
class LeitnerService {
  /// Nguồn ngẫu nhiên dùng khi xáo trộn hàng đợi.
  ///
  /// Tiêm từ ngoài vào để unit test khoá được kết quả bằng một hạt giống cố
  /// định, thay vì phải chấp nhận thứ tự đổi mỗi lần chạy.
  final Random _random;

  LeitnerService({Random? random}) : _random = random ?? Random();

  /// Hộp thấp nhất và cao nhất.
  static const int minBox = 1;
  static const int maxBox = 5;

  /// Số ngày tối đa chịu duyệt tiến khi tìm ngày ôn kế tiếp.
  ///
  /// Đây là chốt an toàn, không phải luật nghiệp vụ. Lịch thưa nhất là Hộp 5
  /// (mỗi tháng một lần) nên thực tế không bao giờ duyệt quá 31 ngày sau mốc
  /// tối thiểu. Nếu chạm trần này thì chắc chắn bảng lịch đã bị định nghĩa sai,
  /// và thà ném lỗi còn hơn treo máy trong vòng lặp vô tận.
  static const int _maxSearchDays = 400;

  /// Bảng lịch của cả 5 hộp, đúng theo mục 3.1.
  static final Map<int, BoxSchedule> schedules = {
    // Hộp 1 — ôn mỗi ngày, cách tối thiểu 1 ngày.
    1: BoxSchedule(minimumGapDays: 1, matches: (date, cardId) => true),
    // Hộp 2 — Thứ Hai, Thứ Tư, Thứ Sáu.
    2: BoxSchedule(
      minimumGapDays: 2,
      matches: (date, cardId) =>
          date.weekday == DateTime.monday ||
          date.weekday == DateTime.wednesday ||
          date.weekday == DateTime.friday,
    ),
    // Hộp 3 — chỉ Thứ Ba.
    3: BoxSchedule(
      minimumGapDays: 5,
      matches: (date, cardId) => date.weekday == DateTime.tuesday,
    ),
    // Hộp 4 — Thứ Bảy hoặc Chủ Nhật, tuỳ nhóm của thẻ (mục 3.2).
    //
    // Lưu ý về con số "14 ngày" ghi trong mục 3.2: đó KHÔNG phải giãn cách thật.
    // Thẻ chỉ đi qua Hộp 4 đúng một lần — trả lời đúng thì lên thẳng Hộp 5, sai
    // thì rơi về Hộp 1 — nên không tồn tại nhịp lặp 14 ngày nào cả.
    //
    // Giãn cách thật khi người học ôn đúng hạn: thẻ chỉ lên Hộp 4 từ Hộp 3, mà
    // Hộp 3 chỉ đến hạn vào Thứ Ba. Thứ Ba cộng 12 ngày rơi đúng Chủ Nhật, nên
    // nhóm lẻ dừng ngay tại đó (12 ngày) còn nhóm chẵn phải đi tiếp tới Thứ Bảy
    // (18 ngày). Nếu người học ôn muộn thì mốc xuất phát lệch khỏi Thứ Ba và
    // giãn cách trải trong dải 12 đến 18 ngày.
    // Xem `test/schedule_matrix_test.dart` để có bảng số liệu đầy đủ.
    4: BoxSchedule(
      minimumGapDays: 12,
      matches: (date, cardId) => date.weekday == weekendDayForCard(cardId),
    ),
    // Hộp 5 — ngày 15 hằng tháng.
    5: BoxSchedule(
      minimumGapDays: 20,
      matches: (date, cardId) => date.day == 15,
    ),
  };

  /// Chia đôi kho thẻ Hộp 4 theo mã thẻ (mục 3.2).
  ///
  /// Cách băm: cộng mã của từng ký tự trong `id` rồi chia lấy dư cho 2. Chẵn thì
  /// thẻ thuộc nhóm Thứ Bảy, lẻ thì nhóm Chủ Nhật.
  ///
  /// Phải là hàm thuần và ổn định: cùng một `id` thì đời nào cũng phải ra cùng
  /// một nhóm, kể cả sau khi xuất rồi nhập lại dữ liệu. Vì thế cố ý KHÔNG dùng
  /// `id.hashCode` — giá trị đó không được bảo đảm giữ nguyên giữa các phiên
  /// chạy hay giữa các phiên bản Dart.
  static int hashCardId(String cardId) {
    var sum = 0;
    for (final unit in cardId.codeUnits) {
      sum += unit;
    }
    return sum;
  }

  /// Thẻ này ôn Hộp 4 vào Thứ Bảy hay Chủ Nhật.
  static int weekendDayForCard(String cardId) =>
      hashCardId(cardId).isEven ? DateTime.saturday : DateTime.sunday;

  /// Tính ngày đến hạn ôn kế tiếp — tương ứng `tinhNgayOnKeTiep` trong SOP 3.3.
  ///
  /// Cách làm: lấy mốc 00:00 của [current] cộng thêm khoảng cách tối thiểu của
  /// [newBox], rồi duyệt tiến từng ngày cho tới ngày đầu tiên khớp lịch của hộp.
  ///
  /// Ba ví dụ kiểm chứng trong SOP:
  ///   * Hộp 3, Thứ Sáu 01/05 thì tối thiểu 5 ngày là 06/05 (Thứ Tư), Thứ Ba
  ///     gần nhất từ đó là 12/05.
  ///   * Hộp 5, ngày 10/06 thì tối thiểu 20 ngày là 30/06, ngày 15 gần nhất là
  ///     15/07.
  ///   * Hộp 4 nhóm chẵn, Chủ Nhật 04/05 thì tối thiểu 12 ngày là 16/05, Thứ
  ///     Bảy gần nhất là 17/05.
  DateTime calculateNextReviewDate(
    int newBox,
    String cardId,
    DateTime current,
  ) {
    final schedule = schedules[newBox];
    if (schedule == null) {
      throw ArgumentError.value(
        newBox,
        'newBox',
        'Hộp phải nằm trong khoảng $minBox đến $maxBox',
      );
    }

    // Chuẩn hoá về 00:00 trước khi cộng, để giờ trong ngày không làm lệch mốc.
    var candidate = du.DateUtils.addDays(
      du.DateUtils.startOfDay(current),
      schedule.minimumGapDays,
    );

    for (var step = 0; step <= _maxSearchDays; step++) {
      if (schedule.matches(candidate, cardId)) return candidate;
      candidate = du.DateUtils.addDays(candidate, 1);
    }

    throw StateError(
      'Không tìm được ngày ôn cho hộp $newBox sau $_maxSearchDays ngày — '
      'bảng lịch có thể đã bị định nghĩa sai',
    );
  }

  /// Xử lý một lượt trả lời — tương ứng `capNhatTheSauKhiTraLoi` trong SOP 3.4.
  ///
  /// [alreadyFailedThisSession] cho biết thẻ này đã trả lời sai ở đâu đó trong
  /// chính buổi học hiện tại. Cờ này quyết định một luật quan trọng: lượt sửa
  /// sai KHÔNG được tính là lên hộp. Người học sai rồi ngay sau đó nhớ ra thì
  /// chỉ là nhớ ngắn hạn, chưa đủ để coi là đã thuộc.
  ///
  /// Hàm không tự ghi xuống kho: nó trả về [AnswerOutcome] để tầng trên quyết
  /// định lúc nào ghi. Nhờ vậy hàm vẫn thuần và kiểm thử được dễ dàng.
  AnswerOutcome applyAnswer({
    required Flashcard card,
    required bool isCorrect,
    required String logId,
    bool alreadyFailedThisSession = false,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final boxBefore = card.boxNumber;

    final int boxAfter;
    final DateTime nextReviewDate;
    final bool shouldRequeue;
    final int lapseCount;

    if (!isCorrect) {
      // TRẢ LỜI SAI — thẻ rơi thẳng về Hộp 1 và phải ôn lại ngay ngày mai.
      // Thẻ KHÔNG rời hàng đợi: nó quay về cuối hàng để người học gặp lại ngay
      // trong buổi này.
      boxAfter = minBox;
      nextReviewDate = du.DateUtils.addDays(moment, 1);
      shouldRequeue = true;
      lapseCount = card.lapseCount + 1;
    } else if (alreadyFailedThisSession) {
      // TRẢ LỜI ĐÚNG Ở LƯỢT SỬA SAI — thẻ rời hàng đợi, nhưng giữ nguyên Hộp 1
      // và giữ nguyên lịch ngày mai đã đặt lúc trả lời sai. Đây chính là điểm
      // khác biệt then chốt so với một lượt đúng bình thường.
      boxAfter = card.boxNumber;
      nextReviewDate = card.nextReviewDate;
      shouldRequeue = false;
      lapseCount = card.lapseCount;
    } else {
      // TRẢ LỜI ĐÚNG BÌNH THƯỜNG — lên một hộp, trần là Hộp 5.
      boxAfter = card.boxNumber < maxBox ? card.boxNumber + 1 : maxBox;
      nextReviewDate = calculateNextReviewDate(boxAfter, card.id, moment);
      shouldRequeue = false;
      lapseCount = card.lapseCount;
    }

    final updatedCard = card.copyWith(
      boxNumber: boxAfter,
      nextReviewDate: nextReviewDate,
      // Mọi lượt trả lời đều tính là một lần ôn, kể cả lượt sửa sai trong buổi.
      reviewCount: card.reviewCount + 1,
      lapseCount: lapseCount,
      updatedAt: moment,
    );

    final log = StudyLog(
      id: logId,
      cardId: card.id,
      answeredAt: moment,
      isCorrect: isCorrect,
      boxBefore: boxBefore,
      boxAfter: boxAfter,
    );

    return AnswerOutcome(
      updatedCard: updatedCard,
      log: log,
      shouldRequeue: shouldRequeue,
    );
  }

  /// Dựng hàng đợi cho buổi học từ danh sách thẻ đến hạn — mục 3.5.
  ///
  /// Mục 3.5 vừa yêu cầu xáo trộn, vừa yêu cầu ưu tiên hộp thấp lên trước. Hai
  /// điều đó không thể cùng đúng tuyệt đối, nên cách xử lý ở đây là: nhóm thẻ
  /// theo hộp, xáo trộn ngẫu nhiên BÊN TRONG từng nhóm, rồi nối các nhóm lại
  /// theo thứ tự hộp 1 đến 5.
  ///
  /// Nhờ vậy thẻ yếu vẫn được gặp lúc người học còn tỉnh táo, mà thứ tự trong
  /// mỗi nhóm vẫn đổi theo từng buổi nên không sinh ra kiểu thuộc lòng theo vị
  /// trí thay vì thuộc từ.
  List<Flashcard> buildTodayQueue(List<Flashcard> dueCards) {
    if (dueCards.isEmpty) return const [];

    final byBox = <int, List<Flashcard>>{};
    for (final card in dueCards) {
      byBox.putIfAbsent(card.boxNumber, () => <Flashcard>[]).add(card);
    }

    final queue = <Flashcard>[];
    final boxNumbers = byBox.keys.toList()..sort();
    for (final boxNumber in boxNumbers) {
      final group = byBox[boxNumber]!;
      group.shuffle(_random);
      queue.addAll(group);
    }
    return queue;
  }

  /// Kích hoạt thẻ mới từ thư viện vào Hộp 1 — mục 3.6.
  ///
  /// Mỗi ngày chỉ được kích hoạt tối đa [AppSettings.newCardsPerDay] thẻ. Số
  /// suất còn lại do [AppSettings.remainingQuotaOn] tính, dựa trên bộ đếm gắn
  /// với ngày chứ không đếm ngược từ kho thẻ.
  ///
  /// Thẻ vừa kích hoạt được đặt hạn ôn ngay trong ngày hôm nay, để người học
  /// chọn từ mới xong là học được luôn, không phải chờ sang hôm sau.
  ///
  /// [requestedCount] là số thẻ người học muốn kích hoạt; bỏ trống thì lấy hết
  /// số suất còn lại. Danh sách [libraryCards] được lấy theo đúng thứ tự truyền
  /// vào, để phía giao diện toàn quyền quyết định chọn thẻ nào.
  ActivationResult activateNewCards({
    required List<Flashcard> libraryCards,
    required AppSettings settings,
    int? requestedCount,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final today = du.DateUtils.startOfDay(moment);
    final remainingQuota = settings.remainingQuotaOn(today);

    // Số thẻ thật sự kích hoạt là giá trị nhỏ nhất trong ba con số: suất còn
    // lại, số thẻ người học yêu cầu, và số thẻ thư viện thực sự có.
    var takeCount = remainingQuota;
    if (requestedCount != null && requestedCount < takeCount) {
      takeCount = requestedCount;
    }
    if (libraryCards.length < takeCount) {
      takeCount = libraryCards.length;
    }
    if (takeCount <= 0) {
      return ActivationResult(
        activatedCards: const [],
        updatedSettings: settings,
        remainingQuota: remainingQuota,
      );
    }

    final activated = <Flashcard>[];
    for (final card in libraryCards.take(takeCount)) {
      activated.add(
        card.copyWith(
          isActive: true,
          boxNumber: minBox,
          nextReviewDate: today,
          updatedAt: moment,
        ),
      );
    }

    // Bộ đếm chỉ cộng dồn khi vẫn còn trong cùng ngày; sang ngày mới thì đếm
    // lại từ số vừa kích hoạt.
    final isSameDayAsCounter =
        settings.lastActivationDate != null &&
        du.DateUtils.isSameDay(settings.lastActivationDate!, today);
    final updatedSettings = settings.copyWith(
      lastActivationDate: today,
      activatedCountToday: isSameDayAsCounter
          ? settings.activatedCountToday + takeCount
          : takeCount,
    );

    return ActivationResult(
      activatedCards: activated,
      updatedSettings: updatedSettings,
      remainingQuota: remainingQuota - takeCount,
    );
  }
}
