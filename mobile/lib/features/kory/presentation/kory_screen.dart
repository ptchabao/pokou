import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_icon.dart';
import '../../../core/widgets/pokou_illustration.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/presentation/pokou_page_header.dart';
import '../data/kory_model.dart';
import 'kory_controller.dart';
import 'kory_create_screen.dart';
import 'kory_home_widgets.dart';
import 'kory_invite_screen.dart';
import 'kory_journal_screen.dart';
import 'kory_pot_screen.dart';
import 'kory_ui.dart';

/// Kory — l'entrée du module (écran APP-3).
///
/// De haut en bas : l'en-tête des onglets, le bloc du mois avec le geste
/// « Nouvelle cagnotte », la recherche, les filtres en pilules, le carrousel
/// « À la une » des échéances qui approchent, puis la liste.
///
/// Le chiffre en tête est « mes contributions confirmées », jamais un
/// solde : rien n'est détenu par Pokou (BM-01). Le rappel en bas de page
/// le dit en toutes lettres, parce que c'est la question que pose quelqu'un
/// qui voit un montant dans une application.
class KoryScreen extends ConsumerStatefulWidget {
  const KoryScreen({super.key});

  @override
  ConsumerState<KoryScreen> createState() => _KoryScreenState();
}

class _KoryScreenState extends ConsumerState<KoryScreen> {
  final _search = TextEditingController();
  KoryHomeFilter _filter = KoryHomeFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openPot(int potId) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: potId)));

  void _showAll() => setState(() {
    _search.clear();
    _filter = KoryHomeFilter.all;
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pots = ref.watch(koryPotsProvider);
    final summary = ref.watch(korySummaryProvider);
    final items = pots.valueOrNull;
    final toReview = summary.valueOrNull?.toReviewCount ?? 0;
    final open = [...?items?.where((pot) => pot.isOpen)];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppColors.accentPrimary,
        onRefresh: () async {
          refreshKory(ref);
          await ref.read(koryPotsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // Le même en-tête que l'Accueil : la ligne du dessous passe en
            // terre cuite quand des contributions attendent ma confirmation.
            SliverToBoxAdapter(
              child: PokouPageHeader(
                title: l.koryTitle,
                subtitle: toReview > 0
                    ? l.koryToReview('$toReview')
                    : l.korySubtitle,
                emphasized: toReview > 0,
                // Le logo du module (guide des logos, novembre 2026).
                leading: const PokouModuleLogo(PokouModule.kory, size: 38),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: KoryHomeHero(
                  monthTotal: summary.valueOrNull?.monthConfirmedTotal,
                  monthLoading: summary.isLoading,
                  activeCount: items == null ? null : open.length,
                  statsLoading: items == null && pots.isLoading,
                  collectedTotal: open.fold(
                    0,
                    (sum, pot) => sum + pot.confirmedTotal,
                  ),
                  onCreate: () => openKoryCreate(context, ref),
                  onJoin: () => _join(context, ref),
                  onJournal: items == null || items.isEmpty
                      ? null
                      : () => _openJournal(items),
                ),
              ),
            ),
            ...pots.when(
              loading: () => const [
                SliverToBoxAdapter(child: KoryHomeSkeleton()),
                SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
              error: (_, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120),
                    child: Center(
                      child: KoryHomeMessage(
                        illustration: PokouIllustrations.offline,
                        title: l.koryUnavailable,
                        message: l.modulesCheckNetwork,
                        actions: [
                          KoryHomePillButton(
                            icon: Icons.refresh,
                            label: l.actionRetry,
                            onPressed: () => refreshKory(ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              data: (items) => items.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 120),
                          child: Center(
                            // Un état vide qui GUIDE : les deux entrées sont là.
                            child: KoryHomeMessage(
                              illustration: PokouIllustrations.kory,
                              title: l.koryNone,
                              message: l.koryNoneBody,
                              actions: [
                                KoryHomePillButton(
                                  icon: Icons.add,
                                  label: l.koryCreate,
                                  onPressed: () => openKoryCreate(context, ref),
                                ),
                                KoryHomePillButton(
                                  quiet: true,
                                  icon: Icons.key_outlined,
                                  label: l.koryJoinTitle,
                                  onPressed: () => _join(context, ref),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]
                  : _content(l, items, open.length),
            ),
          ],
        ),
      ),
    );
  }

  /// La page quand il y a des cagnottes : recherche, filtres, « À la une »,
  /// liste, et le rappel « wallet à wallet ».
  List<Widget> _content(L l, List<KoryPot> items, int openCount) {
    // Un filtre n'est proposé que s'il a de quoi montrer.
    final filters = [
      for (final filter in KoryHomeFilter.values)
        if (filter == KoryHomeFilter.all || items.any(filter.matches)) filter,
    ];
    final filter = filters.contains(_filter) ? _filter : KoryHomeFilter.all;
    final query = _fold(_search.text);
    final narrowed = query.isNotEmpty || filter != KoryHomeFilter.all;
    final shown = [
      for (final pot in items)
        if (filter.matches(pot) &&
            (query.isEmpty || _fold(pot.title).contains(query)))
          pot,
    ];
    // « À la une » : les collectes ouvertes qui ont une échéance, la plus
    // proche d'abord. Une recherche ou un filtre la replie : on cherche
    // alors dans la liste, pas dans une vitrine.
    final featured = narrowed
        ? const <KoryPot>[]
        : (items.where((pot) => pot.isOpen && pot.dueAt != null).toList()
                ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!)))
              .take(6)
              .toList();

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: KoryHomeSearchField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            onClear: () => setState(_search.clear),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: KoryHomeFilterBar(
            filters: filters,
            selected: filter,
            onSelected: (next) => setState(() => _filter = next),
          ),
        ),
      ),
      if (featured.isNotEmpty) ...[
        SliverToBoxAdapter(child: KoryHomeSectionTitle(l.koryHomeFeatured)),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Toutes les cartes à la hauteur de la plus haute, quelle que
            // soit la taille du texte.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, pot) in featured.indexed)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: i == 0 ? 0 : 12,
                      ),
                      child: KoryFeaturedCard(
                        pot: pot,
                        onTap: () => _openPot(pot.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      SliverToBoxAdapter(
        child: KoryHomeSectionTitle(
          l.koryMyPots,
          trailing: openCount > 0 ? l.koryActiveCount('$openCount') : null,
        ),
      ),
      if (shown.isEmpty)
        SliverToBoxAdapter(
          child: KoryHomeMessage(
            illustration: PokouIllustrations.searchEmpty,
            illustrationHeight: 120,
            title: l.koryHomeNoMatch,
            message: l.koryHomeNoMatchBody,
            actions: [
              KoryHomePillButton(
                quiet: true,
                label: l.koryHomeShowAll,
                onPressed: _showAll,
              ),
            ],
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => KoryPotCard(pot: shown[index]),
          ),
        ),
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 120),
          child: _TrustCard(),
        ),
      ),
    ];
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.koryJoinTitle),
        content: TextField(
          contextMenuBuilder: pokouContextMenuBuilder,
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.koryJoinHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l.koryJoin),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !context.mounted) return;
    // KOR-10 : on voit ce qu'on rejoint AVANT de le rejoindre.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => KoryInviteScreen(code: code)));
    refreshKory(ref);
  }

  /// « Journal » : le journal d'une collecte, choisie dans la liste.
  Future<void> _openJournal(List<KoryPot> items) async {
    final l = L.of(context);
    if (items.length == 1) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KoryJournalScreen(potId: items.first.id),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<KoryPot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              KorySection(l.koryXWhichJournal),
              for (final pot in items)
                KoryPersonRow(
                  name: pot.title,
                  subtitle: koryKindLabel(l, pot),
                  onTap: () => Navigator.pop(sheetContext, pot),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KoryJournalScreen(potId: picked.id)),
    );
  }
}

/// « mariage » trouve « Mariage », « bapteme » trouve « Baptême » : la
/// recherche ignore la casse et les accents courants.
String _fold(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyy';
  final lower = text.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

/// Une cagnotte dans la liste : la vignette à son initiale, le titre, la
/// barre d'avancement, ce qui est réuni sur ce qui est visé, et le bouton.
///
/// Toute la carte ouvre la cagnotte ; le bouton aussi — c'est là que l'on
/// déclare sa contribution.
class KoryPotCard extends StatelessWidget {
  const KoryPotCard({super.key, required this.pot});

  final KoryPot pot;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final look = KoryKindLook.of(pot);
    final figures = KoryPotFigures.of(pot);
    final round = koryCurrentRound(pot);
    final days = pot.isOpen ? koryDaysLeft(pot) : null;
    final pending = pot.pendingCount ?? 0;
    final period = switch (pot.period) {
      'WEEKLY' => l.koryPeriodWeekly,
      'MONTHLY' => l.koryPeriodMonthly,
      _ => null,
    };
    // « Cagnotte · Kossi », « Tontine · Tour 2 sur 6 », « Cotisation ·
    // 5 000 FCFA par membre, chaque mois ».
    final detail = round != null
        ? l.koryHomeRoundOf(
            '${pot.currentRound ?? round.number}',
            '${pot.rounds.length}',
          )
        : pot.isCotisation && pot.amountPerMember != null && period != null
        ? l.koryPerMember(formatFcfa(pot.amountPerMember!), period)
        : pot.organizerName;
    final subtitle = [
      koryKindLabel(l, pot),
      if (detail != null && detail.isNotEmpty) detail,
    ].join(' · ');
    // Sous le montant : la cible et le pourcentage en TEXTE, pas seulement
    // en barre (section 7.6) ; sans cible, ce que le chiffre représente.
    final target = figures.target;
    final caption = target != null
        ? '${l.koryOnGoal(formatFcfa(target))} · '
              '${l.koryHomePercent('${figures.percent}')}'
        : round?.beneficiaryName != null
        ? l.koryHomeBeneficiary(round!.beneficiaryName!)
        : l.koryTotalConfirmed;
    final signal = !pot.isOpen
        ? KoryStatusPill(
            icon: Icons.lock_outline,
            label: l.koryClosed,
            color: AppColors.textSecondary,
          )
        : pending > 0
        ? KoryStatusPill(
            icon: Icons.hourglass_top,
            label: l.koryToReview('$pending'),
            color: AppColors.securityWarning,
          )
        : days != null
        ? KoryStatusPill(
            icon: days < 0 ? Icons.event_busy_outlined : Icons.schedule,
            label: days < 0 ? l.koryHomeOverdue : l.homeDaysLeft(days),
            color: days <= 3
                ? AppColors.securityCritical
                : AppColors.accentPrimaryDark,
          )
        : null;
    void open() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => KoryPotScreen(potId: pot.id)));

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PotThumb(title: pot.title, look: look, muted: !pot.isOpen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pot.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // La nature et son détail à gauche ; à droite un
                        // seul signal, le plus pressant : clôturée, à
                        // confirmer, ou le temps qui reste. Le titre garde
                        // ainsi toute la largeur.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (signal != null) ...[
                              const SizedBox(width: 8),
                              Flexible(flex: 0, child: signal),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (figures.value != null) ...[
                KoryProgressBar(value: figures.value!, muted: !pot.isOpen),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatFcfa(figures.amount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    flex: 0,
                    child: KoryHomePillButton(
                      quiet: !pot.isOpen,
                      label: pot.isOpen ? l.koryHomeContribute : l.koryHomeView,
                      onPressed: open,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La vignette d'une cagnotte : son initiale sur l'aplat de sa nature.
/// Clôturée, elle s'éteint — l'œil trie la liste sans la lire.
class _PotThumb extends StatelessWidget {
  const _PotThumb({
    required this.title,
    required this.look,
    required this.muted,
  });

  final String title;
  final KoryKindLook look;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initial = trimmed.isEmpty
        ? ''
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? AppColors.surfaceElevated : look.tint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: initial.isEmpty
            ? Icon(
                Icons.savings_outlined,
                color: muted ? AppColors.textMuted : look.ink,
              )
            : Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: muted ? AppColors.textMuted : look.ink,
                ),
              ),
      ),
    );
  }
}

/// Le rappel du bas de page, à la manière de celui de l'Accueil : Pokou ne
/// touche jamais l'argent, il passe de wallet à wallet.
class _TrustCard extends StatelessWidget {
  const _TrustCard();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: const BoxDecoration(
        gradient: AppGradients.certified,
        borderRadius: AppRadius.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.koryWalletChip,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandOr,
                  ),
                ),
                const SizedBox(height: 6),
                // Fond de marque fixe : le crème ne change pas en sombre.
                Text(
                  l.koryNeverTouches,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: AppColors.neutralCreme,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ExcludeSemantics(
            child: Icon(
              Icons.verified_user_outlined,
              color: AppColors.brandOr,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une pastille d'état : icône ET libellé, jamais la couleur seule (DS-06).
class KoryStatusPill extends StatelessWidget {
  const KoryStatusPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          // Faute de place, le libellé se coupe au lieu de déborder.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
