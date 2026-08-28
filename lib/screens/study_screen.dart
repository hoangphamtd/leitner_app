import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/study_provider.dart';
import '../services/study_session.dart';
import '../widgets/card_faces.dart';
import '../widgets/content_width_limit.dart';
import '../widgets/flip_card.dart';

/// Màn hình Học.
///
/// Vòng lặp buổi học chỉ kết thúc khi hàng đợi rỗng — thẻ trả lời sai quay lại
/// cuối hàng nên người học sẽ gặp lại ngay trong buổi. Toàn bộ luật đó nằm ở
/// [StudySession]; màn hình chỉ hiển thị và chuyển thao tác xuống provider.
class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final study = context.watch<StudyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          study.status == StudyStatus.finished
              ? 'Hoàn thành'
              : 'Còn ${study.remainingCount} thẻ',
        ),
        centerTitle: true,
        bottom: study.status == StudyStatus.studying
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: study.progress),
              )
            : null,
      ),
      body: SafeArea(
        child: switch (study.status) {
          StudyStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          StudyStatus.error => _StudyError(message: study.errorMessage),
          StudyStatus.finished => _SessionSummary(stats: study.stats),
          StudyStatus.idle => const Center(
            child: Text('Chưa có buổi học nào đang diễn ra.'),
          ),
          StudyStatus.studying => _StudyBody(study: study),
        },
      ),
    );
  }
}

class _StudyError extends StatelessWidget {
  final String? message;

  const _StudyError({required this.message});

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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('QUAY LẠI'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyBody extends StatelessWidget {
  final StudyProvider study;

  const _StudyBody({required this.study});

  /// Quãng vuốt tối thiểu để tính là một cú vuốt có chủ ý, tính theo pixel mỗi
  /// giây. Đặt đủ cao để cuộn nhẹ hay chạm run tay không bị hiểu nhầm thành câu
  /// trả lời — trả lời nhầm ở đây khiến thẻ tụt hẳn về Hộp 1.
  static const double _swipeVelocityThreshold = 300;

  @override
  Widget build(BuildContext context) {
    final card = study.currentCard;
    if (card == null) return const SizedBox.shrink();

    return ContentWidthLimit(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                // Vuốt trái là SAI, vuốt phải là ĐÚNG.
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() < _swipeVelocityThreshold) return;
                  _answer(context, velocity > 0);
                },
                child: FlipCard(
                  showBack: study.isRevealed,
                  onTap: () => context.read<StudyProvider>().reveal(),
                  front: CardFront(card: card),
                  back: CardBack(card: card),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Chỉ cho trả lời sau khi đã lật xem đáp án. Trả lời khi chưa xem mặt
            // sau thì con số thống kê mất hết ý nghĩa.
            if (!study.isRevealed)
              _HintLine(
                icon: Icons.touch_app_rounded,
                text: 'Chạm vào thẻ để xem nghĩa',
              )
            else
              _AnswerButtons(
                onAnswer: (isCorrect) => _answer(context, isCorrect),
              ),
          ],
        ),
      ),
    );
  }

  void _answer(BuildContext context, bool isCorrect) {
    final study = context.read<StudyProvider>();
    // Vuốt cũng phải xem đáp án trước, giống như bấm nút.
    if (!study.isRevealed) {
      study.reveal();
      return;
    }
    study.answer(isCorrect);
  }
}

class _HintLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// Hai nút lớn SAI và ĐÚNG.
class _AnswerButtons extends StatelessWidget {
  final void Function(bool isCorrect) onAnswer;

  const _AnswerButtons({required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => onAnswer(false),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.close_rounded),
            label: const Text('SAI'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => onAnswer(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('ĐÚNG'),
          ),
        ),
      ],
    );
  }
}

/// Màn hình chúc mừng khi hàng đợi đã rỗng.
class _SessionSummary extends StatelessWidget {
  final SessionStats? stats;

  const _SessionSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final data = stats;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: 72, color: scheme.tertiary),
            const SizedBox(height: 16),
            Text(
              'Xong buổi hôm nay!',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            if (data != null) ...[
              _StatRow(label: 'Số thẻ đã học', value: '${data.cardsCompleted}'),
              _StatRow(label: 'Lượt trả lời', value: '${data.totalAnswers}'),
              _StatRow(label: 'Trả lời đúng', value: '${data.correctAnswers}'),
              _StatRow(label: 'Trả lời sai', value: '${data.wrongAnswers}'),
              _StatRow(
                label: 'Tỉ lệ đúng',
                value: '${data.accuracyPercent.toStringAsFixed(0)}%',
              ),
              if (data.cardsLapsed > 0)
                _StatRow(
                  label: 'Thẻ phải học lại',
                  value: '${data.cardsLapsed}',
                ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('VỀ TRANG CHỦ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
