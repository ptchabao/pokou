import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/sticker_models.dart';
import 'sticker_image.dart';
import 'sticker_packs_screen.dart';
import 'sticker_providers.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// Le panneau de stickers, sous la barre de saisie.
///
/// ── Ce qui se passe au toucher ─────────────────────────────────────────
///
/// Le sticker PART. Il n'y a pas d'aperçu, pas de confirmation, pas de
/// « voulez-vous vraiment ». C'est ce que fait toute messagerie, et c'est
/// ce que veut dire un sticker : une réaction rapide. Une étape de plus le
/// rendrait plus lent que d'écrire « 👍 ».
///
/// L'appui LONG, lui, met en favori — le geste secondaire pour l'action
/// secondaire.
///
/// ── Trois listes, et elles ne se confondent pas ────────────────────────
///
/// Les RÉCENTS se remplissent tout seuls et se chassent les uns les autres.
/// Les FAVORIS sont choisis, et restent tant qu'on ne les retire pas. Les
/// PACKS sont le catalogue installé. Fondre les deux premiers ferait
/// disparaître un sticker qu'on avait explicitement mis de côté, le jour où
/// on en envoie trente autres.
class StickerPanel extends ConsumerStatefulWidget {
  const StickerPanel({super.key, required this.height, required this.onSend});

  final double height;

  /// Appelé avec le sticker touché. L'envoi lui-même appartient à l'écran
  /// de conversation — le panneau ne connaît ni le destinataire, ni le
  /// chiffrement, et ne doit pas les connaître.
  final void Function(Sticker sticker) onSend;

  @override
  ConsumerState<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends ConsumerState<StickerPanel> {
  /// -2 = récents, -1 = favoris, sinon l'id du pack. Les valeurs négatives
  /// ne peuvent entrer en collision avec un identifiant de pack, qui est
  /// toujours positif.
  static const _tabRecents = -2;
  static const _tabFavorites = -1;

  int _tab = _tabRecents;
  final _searchController = TextEditingController();
  String _query = '';
  bool _searching = false;

  /// La recherche attend qu'on ait fini de taper.
  ///
  /// Sans ce délai, `_query` changeait à chaque frappe, et chaque valeur
  /// crée sa propre instance de `stickerSearchProvider` — donc un
  /// aller-retour réseau PAR CARACTÈRE. Taper « bravo » en déclenchait
  /// cinq, dont quatre dont personne ne verra jamais le résultat.
  ///
  /// 300 ms : au-delà, la liste paraît traîner derrière la frappe ; en
  /// deçà, une saisie normale repasse à un appel par lettre.
  Timer? _searchDebounce;

  L get _l => L.of(context);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    // Vider le champ prend effet TOUT DE SUITE : attendre 300 ms avant de
    // revenir aux onglets ferait clignoter un « aucun résultat » sur un
    // écran qu'on vient de quitter.
    if (value.trim().isEmpty) {
      if (_query.isNotEmpty) setState(() => _query = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _toggleSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> _openPacks() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StickerPacksScreen()));
    // La gestion des packs a pu installer, retirer ou créer : le panneau
    // relit plutôt que de deviner ce qui a changé.
    if (mounted) await ref.read(stickerPanelProvider.notifier).load();
  }

  Future<void> _createSticker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StickerPacksScreen(startWithCreation: true),
      ),
    );
    if (mounted) await ref.read(stickerPanelProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stickerPanelProvider);

    return SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: AppColors.chatComposerBg,
        child: Column(
          children: [
            _header(state),
            Expanded(child: _body(state)),
            _categoryBar(state),
          ],
        ),
      ),
    );
  }

  // ── En-tête : recherche et gestion ───────────────────────────────────

  Widget _header(StickerPanelState state) {
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                    width: 0.5,
                  ),
                ),
                child: TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _l.stickerSearchHint,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.accentPrimaryDark,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 8,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _toggleSearch,
              icon: const Icon(Icons.close_rounded, size: 20),
              color: AppColors.textSecondary,
              tooltip: _l.actionClose,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search_rounded, size: 21),
            color: AppColors.textSecondary,
            tooltip: _l.stickerSearchHint,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _categoryBar(StickerPanelState state) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              children: [
                _tabButton(
                  key: _tabRecents,
                  child: Icon(
                    Icons.access_time_rounded,
                    size: 20,
                    color: _tab == _tabRecents
                        ? AppColors.accentPrimaryDark
                        : AppColors.textMuted,
                  ),
                ),
                _tabButton(
                  key: _tabFavorites,
                  child: Icon(
                    _tab == _tabFavorites
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 21,
                    color: _tab == _tabFavorites
                        ? const Color(0xFFF59E0B)
                        : AppColors.textMuted,
                  ),
                ),
                for (final pack in state.packs)
                  _tabButton(
                    key: pack.id,
                    child: pack.thumbnailMediaId == null
                        ? Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pack.name.characters
                                  .take(2)
                                  .toString()
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _tab == pack.id
                                    ? AppColors.accentPrimaryDark
                                    : AppColors.textMuted,
                              ),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: StickerImage(
                              mediaId: pack.thumbnailMediaId!,
                              size: 26,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openPacks,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 21),
            color: AppColors.textSecondary,
            tooltip: _l.stickerManagePacks,
          ),
        ],
      ),
    );
  }

  Widget _tabButton({required int key, required Widget child}) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => setState(() => _tab = key),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accentPrimary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(
                    color: AppColors.accentPrimary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Corps ────────────────────────────────────────────────────────────

  Widget _body(StickerPanelState state) {
    if (_query.trim().isNotEmpty) {
      final results = ref.watch(stickerSearchProvider(_query));
      return results.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _message(_l.stickerNoResult),
        data: (items) =>
            items.isEmpty ? _message(_l.stickerNoResult) : _grid(items, state),
      );
    }

    if (state.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Rien du tout : on propose le catalogue plutôt qu'une page blanche
    if (state.isEmpty) {
      return _grid(const [], state);
    }

    final items = switch (_tab) {
      _tabRecents when state.recents.isEmpty =>
        state.packs.isEmpty ? const <Sticker>[] : state.packs.first.stickers,
      _tabRecents => state.recents,
      _tabFavorites => state.favorites,
      _ =>
        state.packs
            .where((p) => p.id == _tab)
            .expand((p) => p.stickers)
            .toList(),
    };

    if (items.isEmpty) {
      if (_tab == _tabFavorites) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_outline_rounded,
                size: 40,
                color: AppColors.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                'Aucun favori pour le moment',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Touchez longuement un sticker pour l’ajouter aux favoris',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      }
      return _message(_l.stickerEmptyPanel);
    }
    return _grid(items, state);
  }

  Widget _message(String text) => Center(
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _grid(List<Sticker> items, StickerPanelState state) {
    final favoris = state.favoriteIds;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 88,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _createStickerCell();
        final sticker = items[index - 1];
        return _StickerCell(
          sticker: sticker,
          isFavorite: favoris.contains(sticker.id),
          onTap: () => widget.onSend(sticker),
          onLongPress: () async {
            final etait = favoris.contains(sticker.id);
            await ref
                .read(stickerPanelProvider.notifier)
                .toggleFavorite(sticker);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                content: Text(
                  etait ? _l.stickerFavoriteRemoved : _l.stickerFavoriteAdded,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _createStickerCell() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _createSticker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 5),
              Text(
                _l.stickerCreateFromPhoto,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerCell extends StatefulWidget {
  const _StickerCell({
    required this.sticker,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  final Sticker sticker;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_StickerCell> createState() => _StickerCellState();
}

class _StickerCellState extends State<_StickerCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        widget.onTap();
      },
      onLongPress: () {
        unawaited(HapticFeedback.mediumImpact());
        widget.onLongPress();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: StickerImage(mediaId: widget.sticker.mediaId, size: 64),
              ),
              if (widget.isFavorite)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
