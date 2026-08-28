import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'hive_registrar.g.dart';
import 'app.dart';
import 'data/sample_vocabulary.dart';
import 'providers/backup_provider.dart';
import 'providers/deck_provider.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/study_provider.dart';
import 'repositories/card_repository.dart';
import 'repositories/hive_card_repository.dart';
import 'repositories/hive_session_state_repository.dart';
import 'repositories/hive_settings_repository.dart';
import 'repositories/hive_study_log_repository.dart';
import 'repositories/session_state_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/study_log_repository.dart';
import 'services/diagnostics_service.dart';
import 'services/leitner_service.dart';
import 'services/pronunciation_service.dart';
import 'services/vocabulary_importer.dart';
import 'utils/logger.dart';

final Logger _log = const Logger('main');

Future<void> main() {
  // Chạy toàn bộ app trong một vùng có bắt lỗi.
  //
  // `FlutterError.onError` chỉ bắt lỗi phát sinh trong lúc dựng giao diện. Lỗi
  // bất đồng bộ — hỏng khi mở kho, khi gọi API của trình duyệt — lọt hết ra
  // ngoài và biến mất vào console. Ở chế độ đã cài vào màn hình chính thì không
  // ai mở được console, nên những lỗi đó coi như tàng hình. Vùng này gom chúng
  // lại để dải đỏ hiện lên được.
  return runZonedGuarded(_khoiDong, (error, stack) {
    DiagnosticsService.instance.recordDartError(error);
  })!;
}

Future<void> _khoiDong() async {
  // Bấm giờ ngay từ dòng đầu: mọi con số ở màn hình Chẩn đoán đều tính từ đây.
  final chanDoan = DiagnosticsService.instance..start();
  final swBootstrap = Stopwatch()..start();

  WidgetsFlutterBinding.ensureInitialized();
  chanDoan.hookFlutterErrors();

  // Trên web, Hive CE lưu xuống IndexedDB của trình duyệt. Không cần chỉ định
  // thư mục, cũng không cần quyền gì — toàn bộ dữ liệu nằm trên máy người học.
  await Hive.initFlutter();

  // Phải đăng ký adapter TRƯỚC khi mở bất kỳ hộp nào, nếu không Hive sẽ không
  // biết cách đọc lại các đối tượng đã lưu.
  Hive.registerAdapters();

  final CardRepository cardRepository = HiveCardRepository();
  final StudyLogRepository logRepository = HiveStudyLogRepository();
  final SettingsRepository settingsRepository = HiveSettingsRepository();
  final SessionStateRepository sessionStateRepository =
      HiveSessionStateRepository();

  // Mở kho là khâu chạm ổ đĩa nặng nhất lúc khởi động, nên đo riêng.
  final swHive = Stopwatch()..start();
  await cardRepository.init();
  await logRepository.init();
  await settingsRepository.init();
  await sessionStateRepository.init();
  swHive.stop();
  chanDoan.hiveInitMs = swHive.elapsedMilliseconds;

  final swSeed = Stopwatch()..start();
  final daMoi = await _seedSampleVocabularyIfEmpty(cardRepository);
  swSeed.stop();
  if (daMoi) chanDoan.seedMs = swSeed.elapsedMilliseconds;

  final leitner = LeitnerService();
  final pronunciation = PronunciationService();

  swBootstrap.stop();
  chanDoan.bootstrapMs = swBootstrap.elapsedMilliseconds;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DeckProvider(
            cardRepository: cardRepository,
            logRepository: logRepository,
            settingsRepository: settingsRepository,
            sessionStateRepository: sessionStateRepository,
            leitner: leitner,
          )..refresh(),
        ),
        ChangeNotifierProvider(
          create: (_) => StudyProvider(
            cardRepository: cardRepository,
            logRepository: logRepository,
            sessionStateRepository: sessionStateRepository,
            leitner: leitner,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              LibraryProvider(cardRepository: cardRepository)..refresh(),
        ),
        ChangeNotifierProvider(
          create: (_) => BackupProvider(
            cardRepository: cardRepository,
            logRepository: logRepository,
            settingsRepository: settingsRepository,
            sessionStateRepository: sessionStateRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            repository: settingsRepository,
            pronunciation: pronunciation,
          )..load(),
        ),
      ],
      child: const LeitnerApp(),
    ),
  );
}

/// Mồi bộ từ vựng mẫu vào thư viện ở lần chạy đầu tiên.
///
/// Chỉ chạy khi kho thẻ hoàn toàn rỗng, để không bao giờ ghi đè lên dữ liệu học
/// thật của người dùng. Thẻ nạp vào nằm im trong thư viện với `isActive = false`
/// — người học phải chủ động kích hoạt thì mới vào vòng học.
/// Trả về true nếu thật sự có mồi dữ liệu, để màn hình Chẩn đoán biết con số
/// đo được có ý nghĩa hay chỉ là lần chạy thường.
Future<bool> _seedSampleVocabularyIfEmpty(CardRepository repository) async {
  final existing = await repository.getAll();
  if (existing.isNotEmpty) return false;

  final result = VocabularyImporter().importFromMaps(
    sampleVocabulary,
    existing,
  );
  if (result.errors.isNotEmpty) {
    // Dữ liệu mẫu là hằng số trong mã nguồn nên lỗi ở đây nghĩa là lập trình
    // viên soạn sai, phải thấy ngay chứ không được bỏ qua.
    _log.error('Bộ từ vựng mẫu có mục hỏng: ${result.errors.join("; ")}');
  }
  await repository.saveAll(result.newCards);
  _log.info('Đã mồi ${result.importedCount} từ vựng mẫu vào thư viện');
  return true;
}
