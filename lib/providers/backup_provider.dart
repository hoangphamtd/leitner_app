import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../repositories/card_repository.dart';
import '../repositories/session_state_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/study_log_repository.dart';
import '../services/backup_service.dart';
import '../utils/file_io/file_io.dart';
import '../utils/logger.dart';

/// Kết quả một lượt nhập dữ liệu.
class ImportOutcome {
  final int cardCount;
  final int logCount;

  const ImportOutcome({required this.cardCount, required this.logCount});
}

/// Điều phối việc xuất và nhập sao lưu.
class BackupProvider extends ChangeNotifier {
  final CardRepository cardRepository;
  final StudyLogRepository logRepository;
  final SettingsRepository settingsRepository;
  final SessionStateRepository sessionStateRepository;
  final BackupService service;
  final FileIo fileIo;
  final Logger _log = const Logger('BackupProvider');

  BackupProvider({
    required this.cardRepository,
    required this.logRepository,
    required this.settingsRepository,
    required this.sessionStateRepository,
    this.service = const BackupService(),
    this.fileIo = const FileIo(),
  });

  bool _busy = false;

  /// Đang xuất hoặc nhập. Giao diện dựa vào đây để khoá nút, tránh bấm hai lần.
  bool get isBusy => _busy;

  /// Gom toàn bộ dữ liệu rồi tải file JSON xuống máy.
  ///
  /// Trả về tên file đã tạo. Ghi lại mốc sao lưu để phần nhắc nhở ở Tổng quan
  /// biết đường tính.
  Future<String> exportToFile({DateTime? now}) async {
    final moment = now ?? DateTime.now();
    _setBusy(true);
    try {
      final data = BackupData(
        cards: await cardRepository.getAll(),
        logs: await logRepository.getAll(),
        settings: await settingsRepository.load(),
      );
      final content = service.export(data, now: moment);
      final fileName = service.suggestedFileName(moment);

      await fileIo.download(fileName: fileName, content: content);

      // Chỉ đóng dấu SAU khi tải xuống trót lọt. Đóng dấu trước mà việc tải
      // hỏng thì người dùng tưởng đã sao lưu trong khi chưa có file nào.
      final settings = await settingsRepository.load();
      await settingsRepository.save(settings.copyWith(lastBackupAt: moment));

      _log.info('Đã xuất ${data.cards.length} thẻ ra $fileName');
      return fileName;
    } finally {
      _setBusy(false);
    }
  }

  /// Đọc file người dùng chọn và trả về bản tóm tắt để họ xác nhận.
  ///
  /// Trả về null khi người dùng đóng hộp thoại mà không chọn file. CHƯA ghi gì
  /// vào kho ở bước này — việc ghi đè chỉ xảy ra ở [applyImport].
  Future<({String rawJson, BackupPreview preview})?> pickAndPreview() async {
    final raw = await fileIo.pickTextFile();
    if (raw == null) return null;
    return (rawJson: raw, preview: service.preview(raw));
  }

  /// Ghi đè toàn bộ dữ liệu bằng nội dung file sao lưu.
  ///
  /// Đọc và kiểm tra file XONG XUÔI rồi mới động vào kho: nếu file hỏng thì
  /// [BackupService.import] ném lỗi trước khi một dòng dữ liệu nào bị xoá, nên
  /// người dùng không rơi vào cảnh mất sạch mà cũng chẳng khôi phục được gì.
  Future<ImportOutcome> applyImport(String rawJson) async {
    _setBusy(true);
    try {
      final data = service.import(rawJson);

      await cardRepository.clear();
      await logRepository.clear();
      await cardRepository.saveAll(data.cards);
      for (final log in data.logs) {
        await logRepository.append(log);
      }
      await settingsRepository.save(data.settings);

      // Buổi học dở của phiên cũ trỏ tới những thẻ có thể không còn tồn tại sau
      // khi ghi đè, nên phải bỏ đi.
      await sessionStateRepository.clear();

      _log.warning(
        'Đã ghi đè dữ liệu: ${data.cards.length} thẻ, ${data.logs.length} dòng nhật ký',
      );
      return ImportOutcome(
        cardCount: data.cards.length,
        logCount: data.logs.length,
      );
    } finally {
      _setBusy(false);
    }
  }

  /// Có nên nhắc người dùng sao lưu hay không.
  Future<bool> shouldRemindBackup({DateTime? now}) async {
    final settings = await settingsRepository.load();
    final cards = await cardRepository.getAll();
    return service.shouldRemindBackup(
      lastBackupAt: settings.lastBackupAt,
      cardCount: cards.length,
      now: now ?? DateTime.now(),
    );
  }

  /// Cài đặt hiện tại, dùng để hiển thị mốc sao lưu gần nhất.
  Future<AppSettings> currentSettings() => settingsRepository.load();

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
