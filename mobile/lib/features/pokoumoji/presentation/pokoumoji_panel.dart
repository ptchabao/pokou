import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../data/pokoumoji_runtime.dart';
import '../domain/pokoumoji.dart';
import 'pokoumoji_widgets.dart';

/// Les teintes de carnation (§4 bis) : 1 claire … 4 brun chaud (défaut) … 5
/// foncée. Pastilles du sélecteur.
const _toneColors = {
  '1': Color(0xFFF6D5BF),
  '2': Color(0xFFE2B48A),
  '3': Color(0xFFC28A58),
  '4': Color(0xFF9A6034),
  '5': Color(0xFF5B3820),
};

/// L'onglet Pokoumoji du clavier interne (cahier des charges §05).
///
/// Catégories en bas, grille au milieu, recherche et carnation en haut.
/// Toucher un emoji l'insère au curseur ; toucher un sticker l'ENVOIE (un
/// sticker part toujours seul, jamais dans un texte). L'appui long ouvre
/// les variantes — carnations d'un geste, femme/homme d'un métier — sans
/// jamais imposer un genre.
class PokoumojiPanel extends StatefulWidget {
  const PokoumojiPanel({
    super.key,
    required this.height,
    required this.onInsert,
    required this.onSendSticker,
  });

  final double height;
  final void Function(PokoumojiEntry entry) onInsert;
  final void Function(PokoumojiEntry entry) onSendSticker;

  @override
  State<PokoumojiPanel> createState() => _PokoumojiPanelState();
}

class _PokoumojiPanelState extends State<PokoumojiPanel> {
  static const _recentsTab = '__recents';

  final _rt = PokoumojiRuntime.instance;
  final _search = TextEditingController();
  String _tab = _recentsTab;
  String _query = '';
  bool _searching = false;

  /// Filtre de l'onglet Expressions : `''` = bulles seules, sinon le
  /// personnage.
  String _stickerCharacter = '';

  @override
  void initState() {
    super.initState();
    if (_rt.recents.value.isEmpty) {
      final first = _rt.catalogue.value?.categories.firstOrNull;
      if (first != null) _tab = first.id;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _tap(PokoumojiEntry entry) {
    _rt.markUsed(entry);
    if (entry.isSticker) {
      widget.onSendSticker(entry);
    } else {
      widget.onInsert(entry);
    }
  }

  Future<void> _longPress(PokoumojiCatalogue cat, PokoumojiEntry entry) async {
    final variants = cat.variantsOf(entry.id);
    if (variants.length < 2) return;
    final chosen = await showModalBottomSheet<PokoumojiEntry>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                variants.first.labelFr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in variants)
                    _Cell(
                      entry: v,
                      size: 56,
                      onTap: () => Navigator.of(context).pop(v),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    _rt.rememberVariant(chosen);
    _tap(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final cat = _rt.catalogue.value;
    if (cat == null) return SizedBox(height: widget.height);
    return SizedBox(
      height: widget.height,
      child: ColoredBox(
        color: AppColors.chatComposerBg,
        child: ValueListenableBuilder(
          valueListenable: _rt.prefs,
          builder: (context, prefs, _) => Column(
            children: [
              _header(prefs),
              Expanded(child: _body(cat, prefs)),
              if (!_searching) _categoryBar(cat),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(PokoumojiPrefs prefs) {
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                contextMenuBuilder: pokouContextMenuBuilder,
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  hintText: L.of(context).pokoumojiSearchHint,
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.accentPrimaryDark,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: L.of(context).actionClose,
              onPressed: () => setState(() {
                _searching = false;
                _query = '';
                _search.clear();
              }),
              icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    final tone = prefs.skinTone ?? '4';
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          IconButton(
            tooltip: L.of(context).pokoumojiSearchHint,
            onPressed: () => setState(() => _searching = true),
            icon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
          ),
          const Spacer(),
          // Carnation préférée : un choix libre, local, brun chaud par
          // défaut.
          for (final t in _toneColors.keys)
            Semantics(
              button: true,
              selected: t == tone,
              label: L.of(context).pokoumojiSkinTone(t),
              child: GestureDetector(
                onTap: () => _rt.setSkinTone(t),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _toneColors[t],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t == tone
                          ? AppColors.accentPrimaryDark
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _body(PokoumojiCatalogue cat, PokoumojiPrefs prefs) {
    if (_searching) {
      final hits = cat.search(_query, limit: 120);
      if (_query.trim().isNotEmpty && hits.isEmpty) {
        return Center(
          child: Text(
            L.of(context).pokoumojiNoResults(_query.trim()),
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      return _grid(cat, [
        for (final e in hits) cat.applyPreferences(e.id, prefs) ?? e,
      ]);
    }
    if (_tab == _recentsTab) {
      return ValueListenableBuilder(
        valueListenable: _rt.recents,
        builder: (context, ids, _) {
          final list = [
            for (final id in ids) ?cat.resolve(id),
          ].where(cat.isVisible).toList();
          if (list.isEmpty) {
            return Center(
              child: Text(
                L.of(context).pokoumojiRecentsEmpty,
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return _grid(cat, list);
        },
      );
    }
    final category = cat.categories.where((c) => c.id == _tab).firstOrNull;
    if (category?.group == 'stickers') {
      return Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final (id, label) in [
                  ('', L.of(context).pokoumojiBubbles),
                  ('kimia', 'Kimia'),
                  ('komi', 'Komi'),
                  ('nana_ohene', 'Nana Ohene'),
                  ('nana_ohemaa', 'Nana Ohemaa'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 4,
                    ),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _stickerCharacter == id,
                      onSelected: (_) => setState(() => _stickerCharacter = id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _grid(
              cat,
              cat.stickers(character: _stickerCharacter),
              columns: 4,
            ),
          ),
        ],
      );
    }
    return _grid(cat, [
      for (final e in cat.basesOf(_tab)) cat.applyPreferences(e.id, prefs) ?? e,
    ]);
  }

  Widget _grid(
    PokoumojiCatalogue cat,
    List<PokoumojiEntry> list, {
    int columns = 7,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final e = list[i];
        return _Cell(
          entry: e,
          size: columns == 7 ? 44 : 72,
          onTap: () => _tap(e),
          onLongPress: () => _longPress(cat, e),
          hasVariants: cat.variantsOf(e.id).length > 1,
        );
      },
    );
  }

  Widget _categoryBar(PokoumojiCatalogue cat) {
    final tabs = [
      for (final c in cat.categories)
        if (c.group == 'stickers'
            ? cat.stickers().isNotEmpty
            : cat.basesOf(c.id).isNotEmpty)
          c,
    ];
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: [
          _tabButton(
            _recentsTab,
            L.of(context).pokoumojiRecents,
            Icon(
              Icons.access_time_rounded,
              size: 20,
              color: _tab == _recentsTab
                  ? AppColors.accentPrimaryDark
                  : AppColors.textMuted,
            ),
          ),
          for (final c in tabs)
            _tabButton(
              c.id,
              c.labelFr,
              cat.resolve(c.iconId) == null
                  ? Text(c.labelFr.characters.take(2).toString())
                  : PokoumojiGlyph(
                      entry: cat.resolve(c.iconId)!,
                      size: 26,
                      context: PokoumojiSizeContext.inline,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String id, String label, Widget icon) {
    final selected = _tab == id;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _tab = id),
          child: Container(
            width: 44,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.accentPrimary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(child: icon),
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.entry,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.hasVariants = false,
  });

  final PokoumojiEntry entry;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool hasVariants;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: entry.labelFr,
      hint: hasVariants ? L.of(context).pokoumojiVariantsHint : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PokoumojiGlyph(
              entry: entry,
              size: size,
              context: PokoumojiSizeContext.grid,
            ),
            if (hasVariants)
              Positioned(
                right: 2,
                bottom: 2,
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 10,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
