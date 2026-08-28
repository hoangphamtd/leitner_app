import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/deck_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/busy_button.dart';
import '../widgets/content_width_limit.dart';
import 'card_form_screen.dart';

/// Màn hình Thư viện: xem, tìm, lọc, kích hoạt, thêm sửa xoá thẻ.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          library.hasSelection
              ? 'Đã chọn ${library.selectedIds.length}'
              : 'Thư viện',
        ),
        centerTitle: true,
        leading: library.hasSelection
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Bỏ chọn',
                onPressed: () =>
                    context.read<LibraryProvider>().clearSelection(),
              )
            : null,
        actions: [
          // Chỉ hiện khi đã có thẻ được chọn: lúc chưa chọn gì thì nút này chỉ
          // làm rối thanh tiêu đề, mà người dùng cũng chưa có ý định thao tác
          // hàng loạt.
          if (library.hasSelection)
            TextButton.icon(
              onPressed: () =>
                  context.read<LibraryProvider>().toggleSelectAllVisible(),
              icon: Icon(
                library.allVisibleSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                size: 20,
              ),
              label: Text(
                library.allVisibleSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: library.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ContentWidthLimit(
                child: Column(
                  children: [
                    const _SearchAndFilters(),
                    Expanded(child: _CardList(library: library)),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: library.hasSelection
          ? _SelectionActions(library: library)
          : null,
      floatingActionButton: library.hasSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(context, null),
              icon: const Icon(Icons.add),
              label: const Text('THÊM TỪ'),
            ),
    );
  }

  static Future<void> _openForm(BuildContext context, Flashcard? card) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CardFormScreen(card: card)));
  }
}

/// Ô tìm kiếm và hai hàng bộ lọc.
class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Tìm theo từ hoặc theo nghĩa',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) =>
                context.read<LibraryProvider>().setSearchTerm(value),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả hộp',
                  selected: library.boxFilter == null,
                  onSelected: () =>
                      context.read<LibraryProvider>().setBoxFilter(null),
                ),
                for (var box = 1; box <= 5; box++)
                  _FilterChip(
                    label: 'Hộp $box',
                    selected: library.boxFilter == box,
                    onSelected: () =>
                        context.read<LibraryProvider>().setBoxFilter(box),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Mọi trạng thái',
                  selected: library.activationFilter == ActivationFilter.all,
                  onSelected: () => context
                      .read<LibraryProvider>()
                      .setActivationFilter(ActivationFilter.all),
                ),
                _FilterChip(
                  label: 'Đang học',
                  selected: library.activationFilter == ActivationFilter.active,
                  onSelected: () => context
                      .read<LibraryProvider>()
                      .setActivationFilter(ActivationFilter.active),
                ),
                _FilterChip(
                  label: 'Chưa học',
                  selected:
                      library.activationFilter == ActivationFilter.inactive,
                  onSelected: () => context
                      .read<LibraryProvider>()
                      .setActivationFilter(ActivationFilter.inactive),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  final LibraryProvider library;

  const _CardList({required this.library});

  @override
  Widget build(BuildContext context) {
    final cards = library.visibleCards;

    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            library.totalCount == 0
                ? 'Thư viện đang trống. Bấm THÊM TỪ để tạo thẻ đầu tiên.'
                : 'Không có từ nào khớp với bộ lọc hiện tại.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final card = cards[index];
        return _CardRow(
          card: card,
          selected: library.selectedIds.contains(card.id),
        );
      },
    );
  }
}

class _CardRow extends StatelessWidget {
  final Flashcard card;
  final bool selected;

  const _CardRow({required this.card, required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final library = context.read<LibraryProvider>();

    // Hai vùng chạm tách bạch, theo đúng thông lệ trên điện thoại:
    //   * ô đánh dấu bên trái   -> chọn hoặc bỏ chọn
    //   * phần còn lại của dòng -> mở thẻ ra xem và sửa
    // Cách cũ (chạm cả dòng để chọn, giữ lâu mới sửa) khiến người dùng chạm vào
    // một từ muốn xem lại thì vô tình chọn nó.
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          // Vùng chạm của ô đánh dấu được nới rộng ra xung quanh để ngón tay
          // không phải nhắm đúng cái ô nhỏ.
          InkWell(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(14),
            ),
            onTap: () => library.toggleSelection(card.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? scheme.primary : scheme.outline,
                semanticLabel: selected
                    ? 'Bỏ chọn ${card.word}'
                    : 'Chọn ${card.word}',
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(14),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CardFormScreen(card: card)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.word,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            card.meaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(card: card),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ cho biết thẻ đang ở hộp nào, hoặc còn nằm trong thư viện.
class _StatusBadge extends StatelessWidget {
  final Flashcard card;

  const _StatusBadge({required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isActive = card.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Hộp ${card.boxNumber}' : 'Chưa học',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isActive
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Thanh hành động hiện ra khi có thẻ được chọn.
class _SelectionActions extends StatelessWidget {
  final LibraryProvider library;

  const _SelectionActions({required this.library});

  @override
  Widget build(BuildContext context) {
    final deck = context.watch<DeckProvider>();
    final libraryState = context.watch<LibraryProvider>();
    final selectable = library.selectedInactiveCards.length;
    final quota = deck.remainingQuota;
    final canActivate = selectable > 0 && quota > 0;
    // Hai thao tác này đều ghi dữ liệu, nên khoá cả hai khi một trong hai đang
    // chạy: xoá thẻ giữa lúc đang kích hoạt sẽ để lại kho ở trạng thái nửa vời.
    final dangBan = deck.isBusy || libraryState.isBusy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectable > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Chọn $selectable từ chưa học · hôm nay còn $quota suất',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: BusyButton(
                    isBusy: dangBan,
                    onPressed: () => _confirmDelete(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icons.delete_outline,
                    label: 'XOÁ',
                    filled: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: BusyButton(
                    isBusy: dangBan,
                    onPressed: canActivate ? () => _activate(context) : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: Icons.play_arrow_rounded,
                    label: 'ĐƯA VÀO HỘP 1',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activate(BuildContext context) async {
    final libraryProvider = context.read<LibraryProvider>();
    final deckProvider = context.read<DeckProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final chosen = libraryProvider.selectedInactiveCards;
    try {
      final added = await deckProvider.activateSpecificCards(chosen);
      await libraryProvider.applyActivated(added);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added.length < chosen.length
                ? 'Đã đưa ${added.length} từ vào Hộp 1. '
                      'Số còn lại vượt hạn mức hôm nay.'
                : 'Đã đưa ${added.length} từ vào Hộp 1.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không kích hoạt được. $error')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final libraryProvider = context.read<LibraryProvider>();
    final deckProvider = context.read<DeckProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final count = libraryProvider.selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá từ vựng?'),
        content: Text(
          'Sẽ xoá $count từ khỏi thư viện. '
          'Thao tác này không hoàn tác được.',
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
              minimumSize: const Size(100, 44),
            ),
            child: const Text('XOÁ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removed = await libraryProvider.deleteSelected();
    await deckProvider.refresh();
    messenger.showSnackBar(SnackBar(content: Text('Đã xoá $removed từ.')));
  }
}
