import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/wallpaper/wallpaper_catalog.dart';
import '../../../core/wallpaper/wallpaper_settings.dart';
import '../../../core/wallpaper/wallpaper_view.dart';
import '../../../l10n/app_localizations.dart';

/// « Fond d'écran des discussions » : le fond par défaut de toutes les
/// discussions ([scope] `null`, depuis les Réglages), ou celui d'UNE
/// discussion ([scope] `contact:<id>` / `group:<id>`, depuis son menu).
///
/// Le choix s'applique dès le toucher, comme les autres réglages
/// d'apparence (Thème, Langue) : l'aperçu en haut montre déjà le résultat,
/// un bouton « Valider » n'ajouterait qu'un geste.
class ChatWallpaperScreen extends ConsumerStatefulWidget {
  const ChatWallpaperScreen({super.key, this.scope, this.chatName});

  final String? scope;

  /// Le nom de la discussion, rappelé sous le titre.
  final String? chatName;

  @override
  ConsumerState<ChatWallpaperScreen> createState() =>
      _ChatWallpaperScreenState();
}

class _ChatWallpaperScreenState extends ConsumerState<ChatWallpaperScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: WallpaperFamily.values.length,
    vsync: this,
  );

  /// L'intensité pendant que le curseur glisse ; enregistrée au lâcher.
  double? _dragging;
  bool _tabPlaced = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _familyLabel(L l, WallpaperFamily family) => switch (family) {
    WallpaperFamily.unis => l.wallpaperFamilyUnis,
    WallpaperFamily.motifs => l.wallpaperFamilyMotifs,
    WallpaperFamily.paysages => l.wallpaperFamilyPaysages,
    WallpaperFamily.fetes => l.wallpaperFamilyFetes,
  };

  String _meaning(L l, WallpaperCatalog catalog, Wallpaper w) =>
      w.id == catalog.defaultId ? l.wallpaperDefaultBadge : w.meaning;

  void _choose(Wallpaper w) {
    ref
        .read(chatWallpaperProvider.notifier)
        .choose(
          widget.scope,
          WallpaperChoice(id: w.id, intensity: w.intensityDefault),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final catalog = ref.watch(wallpaperCatalogProvider).valueOrNull;
    final settings = ref.watch(chatWallpaperProvider);
    final scope = widget.scope;
    final own = scope == null ? settings.global : settings.perChat[scope];
    final followsDefault = scope != null && own == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(scope == null ? l.wallpaperTitle : l.wallpaperMenu),
      ),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : _body(l, catalog, settings, own, followsDefault),
    );
  }

  Widget _body(
    L l,
    WallpaperCatalog catalog,
    ChatWallpaperSettings settings,
    WallpaperChoice? own,
    bool followsDefault,
  ) {
    final effective = settings.resolve(widget.scope);
    final wallpaper = catalog.byId(effective?.id);
    final intensity =
        _dragging?.round() ??
        effective?.intensity ??
        wallpaper.intensityDefault;
    // Ouvre l'onglet de la famille du fond en cours, une seule fois.
    if (!_tabPlaced) {
      _tabPlaced = true;
      _tabs.index = WallpaperFamily.values.indexOf(wallpaper.family);
    }
    final today = ref.watch(wallpaperClockProvider)();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.chatName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              l.wallpaperOnlyFor(widget.chatName!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _Preview(
            wallpaper: wallpaper,
            intensity: intensity,
            isDefault: wallpaper.id == catalog.defaultId,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: wallpaper.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: '  ·  ${_meaning(l, catalog, wallpaper)}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (wallpaper.intensityAdjustable)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                Text(
                  l.wallpaperIntensity,
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                Expanded(
                  child: Slider(
                    value: intensity.toDouble(),
                    min: WallpaperChoice.minIntensity.toDouble(),
                    max: WallpaperChoice.maxIntensity.toDouble(),
                    divisions: 16,
                    activeColor: AppColors.accentPrimary,
                    label: '$intensity %',
                    semanticFormatterCallback: (v) => '${v.round()} %',
                    onChanged: (v) => setState(() => _dragging = v),
                    onChangeEnd: (v) {
                      ref
                          .read(chatWallpaperProvider.notifier)
                          .choose(
                            widget.scope,
                            WallpaperChoice(
                              id: wallpaper.id,
                              intensity: v.round(),
                            ),
                          )
                          .whenComplete(() {
                            if (mounted) setState(() => _dragging = null);
                          });
                    },
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '$intensity %',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 8),
        if (widget.scope != null)
          ListTile(
            dense: true,
            leading: Icon(
              followsDefault
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: followsDefault
                  ? AppColors.accentPrimary
                  : AppColors.textMuted,
            ),
            title: Text(l.wallpaperUseDefault),
            subtitle: Text(l.wallpaperUseDefaultHint),
            selected: followsDefault,
            onTap: followsDefault
                ? null
                : () => ref
                      .read(chatWallpaperProvider.notifier)
                      .useDefault(widget.scope!),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              l.wallpaperAllChatsHint,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.accentPrimaryDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentPrimary,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            for (final family in WallpaperFamily.values)
              Tab(text: _familyLabel(l, family)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (final family in WallpaperFamily.values)
                _grid(
                  l,
                  catalog,
                  catalog
                      .family(family)
                      // Un fond de fête hors de sa période reste visible
                      // s'il est celui en cours : on ne fait pas disparaître
                      // le choix de quelqu'un sous ses yeux.
                      .where((w) => w.isOfferedOn(today) || w.id == own?.id)
                      .toList(),
                  selectedId: followsDefault ? null : wallpaper.id,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(
    L l,
    WallpaperCatalog catalog,
    List<Wallpaper> items, {
    required String? selectedId,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.wallpaperFeastsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final w = items[i];
        return _Thumbnail(
          wallpaper: w,
          selected: w.id == selectedId,
          semanticLabel: [
            w.name,
            _meaning(l, catalog, w),
            if (w.id == selectedId) l.wallpaperSelected,
          ].join(', '),
          onTap: () => _choose(w),
        );
      },
    );
  }
}

/// L'aperçu : le fond tel qu'il sera dans la conversation, avec une bulle
/// reçue et une bulle envoyée aux couleurs de l'app.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.wallpaper,
    required this.intensity,
    required this.isDefault,
  });

  final Wallpaper wallpaper;
  final int intensity;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    const radius = Radius.circular(16);
    Widget bubble(String text, {required bool mine}) => Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? AppColors.chatBubbleSent : AppColors.chatBubbleReceived,
          gradient: mine ? AppGradients.sentBubble : null,
          border: mine
              ? null
              : Border.all(color: AppColors.chatBubbleReceivedBorder),
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: mine ? radius : const Radius.circular(4),
            bottomRight: mine ? const Radius.circular(4) : radius,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: mine ? AppColors.textPrimary : AppColors.chatTextReceived,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WallpaperView(
              wallpaper: wallpaper,
              intensity: intensity,
              dark: AppColors.isDark,
              isDefault: isDefault,
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  bubble(l.wallpaperPreviewReceived, mine: false),
                  const SizedBox(height: 8),
                  bubble(l.wallpaperPreviewSent, mine: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.wallpaper,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
  });

  final Wallpaper wallpaper;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.border,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        wallpaper.thumbnail,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                      ),
                      // La vignette voilée comme le sera le fond en sombre.
                      if (dark)
                        ColoredBox(
                          color: WallpaperView.veilColor.withValues(
                            alpha: WallpaperView.darkVeil(wallpaper),
                          ),
                        ),
                      if (selected)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.accentPrimary,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              wallpaper.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.accentPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
