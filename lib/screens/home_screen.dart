import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/deck_provider.dart';
import '../providers/study_provider.dart';
import '../widgets/box_tile.dart';
import '../widgets/content_width_limit.dart';
import 'study_screen.dart';

/// Màn hình Tổng quan — điểm vào của ứng dụng.
///
/// Widget ở đây chỉ đọc số liệu từ [DeckProvider] và gọi phương thức của nó,
/// không tự tính toán gì. Mọi luật nghiệp vụ nằm ở tầng service.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Leitner'), centerTitle: true),
      body: SafeArea(
        child: switch (deck.status) {
          DeckStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          DeckStatus.error => _ErrorView(message: deck.errorMessage),
          DeckStatus.ready => _ReadyView(deck: deck),
        },
      ),
    );
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

  const _ReadyView({required this.deck});

  @override
  Widget build(BuildContext context) {
    return ContentWidthLimit(
      child: RefreshIndicator(
        onRefresh: () => context.read<DeckProvider>().refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
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
    return FilledButton.icon(
      // Không có thẻ đến hạn thì nút bị vô hiệu hoá, đúng yêu cầu Phần 4.
      onPressed: deck.canStudy ? () => _startSession(context) : null,
      icon: const Icon(Icons.school_rounded, size: 26),
      label: Text('HỌC HÔM NAY (${deck.dueCount} từ)'),
    );
  }

  Future<void> _startSession(BuildContext context) async {
    final deckProvider = context.read<DeckProvider>();
    final studyProvider = context.read<StudyProvider>();
    final navigator = Navigator.of(context);

    final queue = await deckProvider.buildTodayQueue();
    if (queue.isEmpty) return;

    studyProvider.start(queue);
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
          OutlinedButton.icon(
            onPressed: canActivate ? () => _activate(context) : null,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('THÊM TỪ MỚI VÀO HỘP 1'),
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
