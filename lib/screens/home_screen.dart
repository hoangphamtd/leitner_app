import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session_state.dart';
import '../providers/backup_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/study_provider.dart';
import '../utils/platform_info/platform_info.dart';
import '../widgets/box_tile.dart';
import '../widgets/busy_button.dart';
import '../widgets/content_width_limit.dart';
import '../widgets/install_guide_sheet.dart';
import 'study_screen.dart';

/// Màn hình Tổng quan — điểm vào của ứng dụng.
///
/// Widget ở đây chỉ đọc số liệu từ [DeckProvider] và gọi phương thức của nó,
/// không tự tính toán gì. Mọi luật nghiệp vụ nằm ở tầng service.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Chỉ hỏi về buổi học dở đúng một lần cho mỗi lần mở app.
  ///
  /// Không có cờ này thì mỗi lần provider báo có thay đổi, hộp thoại lại bật
  /// lên — kể cả ngay sau khi người học vừa trả lời xong.
  bool _askedAboutResume = false;

  /// Đã chạy các bước kiểm tra lúc mở app (mời cài, nhắc sao lưu) hay chưa.
  bool _ranStartupChecks = false;

  /// Có nên hiện dải nhắc sao lưu ở đầu màn hình không.
  bool _showBackupReminder = false;

  /// Số ngày kể từ lần bỏ qua lời mời cài, trước khi được phép mời lại.
  static const int _installPromptCooldownDays = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStartupChecks());
  }

  /// Các việc chỉ làm một lần lúc mở app.
  ///
  /// Chạy sau khung hình đầu tiên để không dựng route giữa lúc đang build, và
  /// chạy tuần tự để lời mời cài không chồng lên hộp thoại buổi học dở.
  Future<void> _runStartupChecks() async {
    if (_ranStartupChecks || !mounted) return;
    _ranStartupChecks = true;

    final backup = context.read<BackupProvider>();
    final needsReminder = await backup.shouldRemindBackup();
    if (!mounted) return;
    if (needsReminder) setState(() => _showBackupReminder = true);

    await _maybeOfferInstall();
  }

  /// Mời cài app vào màn hình chính, nếu đúng lúc.
  ///
  /// Chỉ mời khi hội đủ: đang mở bằng trình duyệt di động, chưa cài, và lần bỏ
  /// qua gần nhất đã quá [_installPromptCooldownDays] ngày.
  Future<void> _maybeOfferInstall() async {
    const info = PlatformInfo();
    if (!info.isMobileBrowser || info.isInstalled) return;

    final settingsProvider = context.read<SettingsProvider>();
    final dismissedAt = settingsProvider.settings.installPromptDismissedAt;
    if (dismissedAt != null) {
      final days = DateTime.now().difference(dismissedAt).inDays;
      if (days < _installPromptCooldownDays) return;
    }

    // Nhường chỗ cho hộp thoại buổi học dở nếu nó đang mở.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    final dismissed = await InstallGuideSheet.show(
      context,
      info.mobilePlatform,
    );
    if (dismissed == null) return;

    // Ghi mốc cho cả hai lựa chọn: người bấm "Đã hiểu" mà chưa cài ngay thì
    // cũng không nên bị hỏi lại vào ngày mai.
    await settingsProvider.markInstallPromptDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();

    // Số liệu được nạp bất đồng bộ nên thời điểm sẵn sàng không rơi vào
    // initState. Chờ khung hình vẽ xong rồi mới mở hộp thoại, để không dựng
    // route ngay giữa lúc đang build.
    if (deck.status == DeckStatus.ready &&
        deck.hasResumableSession &&
        !_askedAboutResume) {
      _askedAboutResume = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askAboutResume(context);
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leitner'), centerTitle: true),
      body: SafeArea(
        child: switch (deck.status) {
          DeckStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          DeckStatus.error => _ErrorView(message: deck.errorMessage),
          DeckStatus.ready => _ReadyView(
            deck: deck,
            showBackupReminder: _showBackupReminder,
            onDismissBackupReminder: () =>
                setState(() => _showBackupReminder = false),
          ),
        },
      ),
    );
  }

  /// Hỏi người học có muốn tiếp tục buổi dở của hôm nay không.
  Future<void> _askAboutResume(BuildContext context) async {
    final deck = context.read<DeckProvider>();
    final saved = deck.resumableSession;
    if (saved == null) return;

    final done = saved.completedCardIds.length;
    final remaining = saved.queueCardIds.length;

    final shouldResume = await showDialog<bool>(
      context: context,
      // Bắt buộc chọn một trong hai, vì bấm ra ngoài rồi bắt đầu buổi mới sẽ
      // âm thầm bỏ mất tiến độ dở dang.
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tiếp tục buổi học dở?'),
        content: Text(
          'Buổi học hôm nay còn dang dở: đã xong $done thẻ, '
          'còn $remaining thẻ chưa học.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('BẮT ĐẦU LẠI'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 44),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('TIẾP TỤC'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldResume == true) {
      await _resumeSession(saved);
    } else if (shouldResume == false) {
      await deck.discardResumableSession();
    }
  }

  /// Dựng lại buổi dở rồi mở thẳng màn hình Học.
  Future<void> _resumeSession(SessionState saved) async {
    final deck = context.read<DeckProvider>();
    final study = context.read<StudyProvider>();
    final navigator = Navigator.of(context);

    final cardsById = await deck.loadCardsById(saved.queueCardIds);
    await study.restore(saved, cardsById);
    if (!mounted) return;

    if (study.status != StudyStatus.studying) {
      // Thẻ trong hàng đợi đã bị xoá hết, không còn gì để tiếp tục.
      await deck.refresh();
      return;
    }

    await navigator.push(
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );
    await deck.refresh();
    study.reset();
  }
}

/// Hiển thị lỗi tường minh kèm nút thử lại, thay vì để màn hình trống.
class _ErrorView extends StatelessWidget {
  final String? message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message ?? 'Đã có lỗi xảy ra.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.read<DeckProvider>().refresh(),
              child: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  final DeckProvider deck;
  final bool showBackupReminder;
  final VoidCallback onDismissBackupReminder;

  const _ReadyView({
    required this.deck,
    required this.showBackupReminder,
    required this.onDismissBackupReminder,
  });

  @override
  Widget build(BuildContext context) {
    return ContentWidthLimit(
      child: RefreshIndicator(
        onRefresh: () => context.read<DeckProvider>().refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (showBackupReminder) ...[
              _BackupReminder(onDismiss: onDismissBackupReminder),
              const SizedBox(height: 16),
            ],
            _BoxGrid(deck: deck),
            const SizedBox(height: 28),
            _StudyButton(deck: deck),
            const SizedBox(height: 16),
            _SummaryLine(deck: deck),
            const SizedBox(height: 28),
            _LibrarySection(deck: deck),
          ],
        ),
      ),
    );
  }
}

/// Lưới năm khối, mỗi khối một hộp.
class _BoxGrid extends StatelessWidget {
  final DeckProvider deck;

  const _BoxGrid({required this.deck});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      // Khối hơi cao hơn rộng để chứa đủ ba dòng chữ trên màn hình hẹp.
      childAspectRatio: 0.72,
      children: [
        for (var boxNumber = 1; boxNumber <= 5; boxNumber++)
          BoxTile(
            boxNumber: boxNumber,
            cardCount: deck.countByBox[boxNumber] ?? 0,
            isDue: deck.boxesDueToday.contains(boxNumber),
          ),
      ],
    );
  }
}

/// Nút lớn bắt đầu buổi học.
class _StudyButton extends StatelessWidget {
  final DeckProvider deck;

  const _StudyButton({required this.deck});

  @override
  Widget build(BuildContext context) {
    return BusyButton(
      // Vừa chặn khi không có thẻ đến hạn (yêu cầu Phần 4), vừa chặn khi đang
      // có thao tác ghi dở dang — vào buổi học giữa lúc kho đang đổi thì hàng
      // đợi dựng ra sẽ thiếu đúng những thẻ vừa được kích hoạt.
      isBusy: deck.isBusy,
      onPressed: deck.canStudy ? () => _startSession(context) : null,
      icon: Icons.school_rounded,
      label: 'HỌC HÔM NAY (${deck.dueCount} từ)',
    );
  }

  Future<void> _startSession(BuildContext context) async {
    final deckProvider = context.read<DeckProvider>();
    final studyProvider = context.read<StudyProvider>();
    final navigator = Navigator.of(context);

    final queue = await deckProvider.buildTodayQueue();
    if (queue.isEmpty) return;

    await studyProvider.start(queue);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );

    // Học xong quay về thì số liệu đã đổi, phải đọc lại từ kho.
    await deckProvider.refresh();
    studyProvider.reset();
  }
}

/// Dòng phụ: chuỗi ngày học liên tiếp và tổng số từ đã thuộc.
class _SummaryLine extends StatelessWidget {
  final DeckProvider deck;

  const _SummaryLine({required this.deck});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SummaryItem(
          icon: Icons.local_fire_department_rounded,
          value: '${deck.streak}',
          label: 'ngày liên tiếp',
          color: scheme.tertiary,
        ),
        Container(width: 1, height: 36, color: scheme.outlineVariant),
        _SummaryItem(
          icon: Icons.workspace_premium_rounded,
          value: '${deck.masteredCount}',
          label: 'từ đã thuộc',
          color: scheme.primary,
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Khu vực kích hoạt từ mới từ thư viện.
///
/// Màn hình Thư viện đầy đủ thuộc giai đoạn sau. Ở đây chỉ có một nút kích hoạt
/// nhanh, vì không có nó thì mọi thẻ đều nằm im với `isActive = false` và màn
/// hình Học sẽ không bao giờ có gì để chạy.
class _LibrarySection extends StatelessWidget {
  final DeckProvider deck;

  const _LibrarySection({required this.deck});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canActivate = deck.libraryCount > 0 && deck.remainingQuota > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thư viện',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Còn ${deck.libraryCount} từ chưa học. '
            'Hôm nay còn ${deck.remainingQuota} suất từ mới.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          BusyButton(
            isBusy: deck.isBusy,
            onPressed: canActivate ? () => _activate(context) : null,
            icon: Icons.add_circle_outline,
            label: 'THÊM TỪ MỚI VÀO HỘP 1',
            filled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _activate(BuildContext context) async {
    final deckProvider = context.read<DeckProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await deckProvider.activateNewCards();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added > 0
                ? 'Đã thêm $added từ mới vào Hộp 1.'
                : 'Không còn suất từ mới cho hôm nay.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thêm được từ mới. $error')),
      );
    }
  }
}

/// Dải nhắc sao lưu, hiện ở đầu màn hình Tổng quan.
///
/// Cố ý nhẹ nhàng chứ không phải hộp thoại chặn đường: đây là lời nhắc, không
/// phải sự cố. Nhưng vẫn cho đóng được, vì người vừa sao lưu xong bằng cách khác
/// mà cứ bị nhắc mãi thì sẽ quen tay bỏ qua mọi cảnh báo.
class _BackupReminder extends StatelessWidget {
  final VoidCallback onDismiss;

  const _BackupReminder({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.backup_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đã lâu chưa sao lưu',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vào Cài đặt để xuất tiến độ ra file, phòng khi trình duyệt '
                  'dọn mất dữ liệu.',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Đóng lời nhắc',
            color: scheme.onTertiaryContainer,
          ),
        ],
      ),
    );
  }
}
