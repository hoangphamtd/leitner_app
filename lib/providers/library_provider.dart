import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/flashcard.dart';
import '../repositories/card_repository.dart';
import '../utils/date_utils.dart' as du;
import '../utils/logger.dart';

/// Bộ lọc theo trạng thái kích hoạt.
enum ActivationFilter {
  /// Tất cả thẻ.
  all,

  /// Chỉ thẻ đã vào vòng học.
  active,

  /// Chỉ thẻ còn nằm trong thư viện.
  inactive,
}

/// Quản lý màn hình Thư viện: tìm kiếm, lọc, chọn nhiều, thêm sửa xoá thẻ.
class LibraryProvider extends ChangeNotifier {
  final CardRepository cardRepository;
  final Uuid uuid;
  final Logger _log = const Logger('LibraryProvider');

  LibraryProvider({required this.cardRepository, this.uuid = const Uuid()});

  List<Flashcard> _allCards = const [];
  bool _loading = true;
  bool get isLoading => _loading;

  String _searchTerm = '';
  String get searchTerm => _searchTerm;

  /// Lọc theo hộp. Null nghĩa là không lọc.
  int? _boxFilter;
  int? get boxFilter => _boxFilter;

  ActivationFilter _activationFilter = ActivationFilter.all;
  ActivationFilter get activationFilter => _activationFilter;

  final Set<String> _selectedIds = <String>{};

  /// Mã các thẻ người dùng đang chọn để thao tác hàng loạt.
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool get hasSelection => _selectedIds.isNotEmpty;

  /// Toàn bộ thẻ đang hiển thị đều đã được chọn hay chưa.
  ///
  /// Nút trên thanh tiêu đề dựa vào đây để đổi giữa "Chọn tất cả" và "Bỏ chọn
  /// tất cả", thay vì bắt người dùng đoán xem bấm vào sẽ ra kết quả nào.
  bool get allVisibleSelected {
    final visible = visibleCards;
    if (visible.isEmpty) return false;
    return visible.every((card) => _selectedIds.contains(card.id));
  }

  int get totalCount => _allCards.length;

  /// Danh sách thẻ sau khi áp dụng tìm kiếm và các bộ lọc.
  ///
  /// Tính lại mỗi lần gọi thay vì lưu sẵn: bộ thẻ chỉ vài nghìn phần tử nên chi
  /// phí không đáng kể, đổi lại không bao giờ có chuyện danh sách đã lọc bị lệch
  /// so với dữ liệu gốc.
  List<Flashcard> get visibleCards {
    final term = _searchTerm.trim().toLowerCase();
    return _allCards.where((card) {
        if (_boxFilter != null && card.boxNumber != _boxFilter) return false;
        switch (_activationFilter) {
          case ActivationFilter.active:
            if (!card.isActive) return false;
          case ActivationFilter.inactive:
            if (card.isActive) return false;
          case ActivationFilter.all:
            break;
        }
        if (term.isEmpty) return true;
        // Tìm cả trong từ lẫn trong nghĩa, vì người học nhớ nghĩa tiếng Việt
        // trước khi nhớ mặt chữ tiếng Anh cũng là chuyện thường.
        return card.word.toLowerCase().contains(term) ||
            card.meaning.toLowerCase().contains(term);
      }).toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
  }

  Future<void> refresh() async {
    try {
      _allCards = await cardRepository.getAll();
      // Bỏ khỏi vùng chọn những thẻ đã không còn tồn tại.
      _selectedIds.removeWhere((id) => !_allCards.any((card) => card.id == id));
    } catch (error, stackTrace) {
      _log.error('Không đọc được thư viện', error, stackTrace);
    }
    _loading = false;
    notifyListeners();
  }

  void setSearchTerm(String value) {
    _searchTerm = value;
    notifyListeners();
  }

  void setBoxFilter(int? box) {
    _boxFilter = box;
    notifyListeners();
  }

  void setActivationFilter(ActivationFilter filter) {
    _activationFilter = filter;
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (!_selectedIds.remove(id)) _selectedIds.add(id);
    notifyListeners();
  }

  /// Chọn tất cả thẻ đang hiển thị, hoặc bỏ chọn hết nếu đã chọn đủ.
  void toggleSelectAllVisible() {
    final visible = visibleCards.map((card) => card.id).toSet();
    if (visible.every(_selectedIds.contains)) {
      _selectedIds.removeAll(visible);
    } else {
      _selectedIds.addAll(visible);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Các thẻ đang chọn mà chưa được kích hoạt.
  ///
  /// Màn hình Thư viện dùng danh sách này để biết còn bao nhiêu thẻ thật sự có
  /// thể đưa vào Hộp 1 — chọn nhầm cả thẻ đang học thì cũng không sao.
  List<Flashcard> get selectedInactiveCards => _allCards
      .where((card) => _selectedIds.contains(card.id) && !card.isActive)
      .toList();

  /// Thêm một thẻ mới do người dùng nhập tay.
  ///
  /// Thẻ mới luôn nằm im trong thư viện với `isActive = false`, đúng như thẻ nạp
  /// từ file — việc đưa vào vòng học phải là một quyết định riêng, để hạn mức
  /// từ mới mỗi ngày ở mục 3.6 không bị lách.
  Future<Flashcard> addCard({
    required String word,
    required String phonetic,
    required String meaning,
    required String exampleSentence,
    String? imagePath,
    DateTime? now,
  }) async {
    final moment = now ?? DateTime.now();
    final card = Flashcard(
      id: uuid.v4(),
      word: word.trim(),
      phonetic: phonetic.trim(),
      meaning: meaning.trim(),
      exampleSentence: exampleSentence.trim(),
      imagePath: (imagePath == null || imagePath.trim().isEmpty)
          ? null
          : imagePath.trim(),
      boxNumber: 1,
      nextReviewDate: du.DateUtils.startOfDay(moment),
      isActive: false,
      createdAt: moment,
      updatedAt: moment,
    );
    await cardRepository.save(card);
    await refresh();
    return card;
  }

  /// Sửa nội dung một thẻ. Không đụng tới hộp và lịch ôn.
  Future<void> updateCard(
    Flashcard card, {
    required String word,
    required String phonetic,
    required String meaning,
    required String exampleSentence,
    String? imagePath,
    DateTime? now,
  }) async {
    final trimmedImage = imagePath?.trim();
    await cardRepository.save(
      card.copyWith(
        word: word.trim(),
        phonetic: phonetic.trim(),
        meaning: meaning.trim(),
        exampleSentence: exampleSentence.trim(),
        imagePath: trimmedImage,
        clearImagePath: trimmedImage == null || trimmedImage.isEmpty,
        // Sửa nội dung cũng là một thay đổi, nên phải đóng dấu thời gian để
        // vòng đồng bộ tương lai nhận ra.
        updatedAt: now ?? DateTime.now(),
      ),
    );
    await refresh();
  }

  Future<void> deleteCard(String id) async {
    await cardRepository.delete(id);
    _selectedIds.remove(id);
    await refresh();
  }

  /// Xoá tất cả thẻ đang chọn.
  Future<int> deleteSelected() async {
    final ids = _selectedIds.toList();
    for (final id in ids) {
      await cardRepository.delete(id);
    }
    _selectedIds.clear();
    await refresh();
    _log.info('Đã xoá ${ids.length} thẻ');
    return ids.length;
  }

  /// Ghi các thẻ vừa được kích hoạt xuống kho rồi đọc lại danh sách.
  Future<void> applyActivated(List<Flashcard> activated) async {
    if (activated.isEmpty) return;
    await cardRepository.saveAll(activated);
    _selectedIds.removeAll(activated.map((card) => card.id));
    await refresh();
  }
}
