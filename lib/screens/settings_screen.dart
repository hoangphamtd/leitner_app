import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_settings.dart';
import '../models/flashcard.dart';
import '../providers/backup_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/pronunciation_service.dart';
import '../widgets/content_width_limit.dart';

/// Màn hình Cài đặt.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Thẻ mẫu dùng để nghe thử giọng đọc.
  static final Flashcard _sampleCard = Flashcard(
    id: 'preview',
    word: 'available',
    phonetic: '/əˈveɪləbl/',
    meaning: 'có sẵn, rảnh',
    exampleSentence: 'The doctor is not available this morning.',
    boxNumber: 1,
    nextReviewDate: DateTime(2025),
    isActive: false,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt'), centerTitle: true),
      body: SafeArea(
        child: settings.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ContentWidthLimit(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _NewCardsSection(settings: settings),
                    const SizedBox(height: 24),
                    _VoiceSection(settings: settings, sample: _sampleCard),
                    const SizedBox(height: 24),
                    _ThemeSection(settings: settings),
                    const SizedBox(height: 24),
                    const _BackupSection(),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Khung chung cho mỗi nhóm cài đặt.
class _Section extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;

  const _Section({required this.title, this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(description!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Số từ mới mỗi ngày (mục 3.6).
class _NewCardsSection extends StatelessWidget {
  final SettingsProvider settings;

  const _NewCardsSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final value = settings.settings.newCardsPerDay;

    return _Section(
      title: 'Số từ mới mỗi ngày',
      description: 'Hôm nay còn ${deck.remainingQuota} suất chưa dùng.',
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: value > 1 ? () => _change(context, value - 5) : null,
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value < 200 ? () => _change(context, value + 5) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _change(BuildContext context, int raw) async {
    final settingsProvider = context.read<SettingsProvider>();
    final deck = context.read<DeckProvider>();
    // Kẹp về khoảng hợp lệ ngay tại đây để nút cộng trừ 5 không nhảy quá biên.
    await settingsProvider.setNewCardsPerDay(raw.clamp(1, 200));
    // Hạn mức đổi thì số suất còn lại của hôm nay cũng đổi theo.
    await deck.refresh();
  }
}

/// Chọn giọng đọc và tốc độ đọc (Phần 5).
class _VoiceSection extends StatelessWidget {
  final SettingsProvider settings;
  final Flashcard sample;

  const _VoiceSection({required this.settings, required this.sample});

  @override
  Widget build(BuildContext context) {
    final voices = settings.voices;
    final rate = settings.settings.ttsRate;

    return _Section(
      title: 'Phát âm',
      description: voices.isEmpty
          ? 'Máy này chưa có giọng đọc tiếng Anh nào. '
                'Nút loa sẽ im lặng cho tới khi cài thêm giọng.'
          : 'Có ${voices.length} giọng tiếng Anh trên máy này.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (voices.isNotEmpty)
            DropdownButtonFormField<TtsVoice?>(
              initialValue: settings.selectedVoice,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Giọng đọc',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: [
                const DropdownMenuItem<TtsVoice?>(
                  value: null,
                  child: Text('Giọng mặc định của máy'),
                ),
                for (final voice in voices)
                  DropdownMenuItem<TtsVoice?>(
                    value: voice,
                    child: Text(
                      '${voice.displayName}  ·  ${voice.locale}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (voice) =>
                  context.read<SettingsProvider>().setVoice(voice),
            ),
          const SizedBox(height: 16),
          Text('Tốc độ đọc: ${(rate * 100).round()}%'),
          Slider(
            value: rate,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            label: '${(rate * 100).round()}%',
            onChanged: (value) =>
                context.read<SettingsProvider>().setRate(value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => context.read<SettingsProvider>().preview(sample),
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('NGHE THỬ'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chọn giao diện sáng hoặc tối.
class _ThemeSection extends StatelessWidget {
  final SettingsProvider settings;

  const _ThemeSection({required this.settings});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Giao diện',
      child: SegmentedButton<AppThemeMode>(
        segments: const [
          ButtonSegment(
            value: AppThemeMode.system,
            label: Text('Theo máy'),
            icon: Icon(Icons.brightness_auto_rounded),
          ),
          ButtonSegment(
            value: AppThemeMode.light,
            label: Text('Sáng'),
            icon: Icon(Icons.light_mode_rounded),
          ),
          ButtonSegment(
            value: AppThemeMode.dark,
            label: Text('Tối'),
            icon: Icon(Icons.dark_mode_rounded),
          ),
        ],
        selected: {settings.settings.themeMode},
        onSelectionChanged: (selection) =>
            context.read<SettingsProvider>().setThemeMode(selection.first),
      ),
    );
  }
}

/// Xuất và nhập tiến độ ra file JSON (Phần 6 của SOP).
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final settings = await context.read<BackupProvider>().currentSettings();
    if (!mounted) return;
    setState(() => _lastBackupAt = settings.lastBackupAt);
  }

  @override
  Widget build(BuildContext context) {
    final backup = context.watch<BackupProvider>();

    return _Section(
      title: 'Sao lưu tiến độ',
      description: _lastBackupAt == null
          ? 'Chưa sao lưu lần nào. Dữ liệu chỉ nằm trong trình duyệt máy này.'
          : 'Lần sao lưu gần nhất: ${_formatDate(_lastBackupAt!)}.',
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: backup.isBusy ? null : _export,
              icon: const Icon(Icons.upload_file),
              label: const Text('XUẤT'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: backup.isBusy ? null : _import,
              icon: const Icon(Icons.download),
              label: const Text('NHẬP'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime moment) {
    final d = moment.day.toString().padLeft(2, '0');
    final m = moment.month.toString().padLeft(2, '0');
    return '$d/$m/${moment.year}';
  }

  Future<void> _export() async {
    final backup = context.read<BackupProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fileName = await backup.exportToFile();
      await _loadLastBackup();
      messenger.showSnackBar(SnackBar(content: Text('Đã tải xuống $fileName')));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không xuất được. $error')),
      );
    }
  }

  Future<void> _import() async {
    final backup = context.read<BackupProvider>();
    final deck = context.read<DeckProvider>();
    final library = context.read<LibraryProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final picked = await backup.pickAndPreview();
      // Người dùng đóng hộp thoại mà không chọn file.
      if (picked == null || !mounted) return;

      // Hỏi xác nhận vì đây là thao tác GHI ĐÈ, không hoàn tác được. Nói rõ số
      // liệu của file để người dùng nhận ra ngay nếu lỡ chọn nhầm bản cũ.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ghi đè toàn bộ dữ liệu?'),
          content: Text(
            'File chứa ${picked.preview.cardCount} thẻ và '
            '${picked.preview.logCount} dòng nhật ký'
            '${picked.preview.exportedAt == null ? '' : ', xuất ngày ${_formatDate(picked.preview.exportedAt!)}'}.\n\n'
            'Toàn bộ dữ liệu hiện có trên máy này sẽ bị XOÁ và thay bằng nội '
            'dung file. Thao tác này không hoàn tác được.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('HUỶ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                minimumSize: const Size(120, 44),
              ),
              child: const Text('GHI ĐÈ'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final outcome = await backup.applyImport(picked.rawJson);

      // Mọi provider đang giữ dữ liệu cũ đều phải đọc lại từ kho.
      await deck.refresh();
      await library.refresh();
      await settings.load();
      await _loadLastBackup();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Đã khôi phục ${outcome.cardCount} thẻ và '
            '${outcome.logCount} dòng nhật ký.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không nhập được. $error')),
      );
    }
  }
}
