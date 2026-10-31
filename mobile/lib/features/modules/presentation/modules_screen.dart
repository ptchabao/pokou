import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../data/module_model.dart';
import 'module_controller.dart';
import 'module_routes.dart';

/// La galerie des modules.
///
/// Trois rayons, et l'ordre n'est pas décoratif : **mes apps** en premier,
/// parce que c'est pour y revenir qu'on ouvre cet écran une deuxième fois ;
/// **recommandés** ensuite, un choix éditorial assumé de l'équipe ;
/// **populaires** en dernier, calculé sur l'usage réel.
///
/// Les trois listes viennent du serveur telles quelles. Les recalculer ici
/// serait impossible de toute façon : « populaire » se mesure sur l'ensemble
/// des utilisateurs, une donnée que le téléphone n'a pas.
class ModulesScreen extends ConsumerStatefulWidget {
  const ModulesScreen({super.key});

  @override
  ConsumerState<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends ConsumerState<ModulesScreen> {
  /// Modules dont la bascule est en cours — l'interrupteur se fige le temps
  /// de l'aller-retour, sinon un appui rapide enverrait deux requêtes
  /// contradictoires.
  final Set<String> _busy = {};

  Future<void> _toggle(AppModule module) async {
    if (_busy.contains(module.slug)) return;
    setState(() => _busy.add(module.slug));
    try {
      final repository = ref.read(moduleRepositoryProvider);
      if (module.isActivated) {
        await repository.deactivate(module.slug);
      } else {
        await repository.activate(module.slug);
      }
      ref.invalidate(moduleCatalogueProvider);
      if (mounted && !module.isActivated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).modulesActivated(module.name))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).modulesEnableFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(module.slug));
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(moduleCatalogueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),

                    tooltip: L.of(context).a11yBack,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.of(context).navModules,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          L.of(context).modulesSubtitle,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: catalogueAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _CenteredMessage(
                  icon: Icons.cloud_off,
                  title: L.of(context).modulesUnavailable,
                  body: L.of(context).modulesCheckNetwork,
                ),
                data: (catalogue) {
                  if (catalogue.isEmpty) {
                    return _CenteredMessage(
                      icon: Icons.extension_outlined,
                      title: L.of(context).modulesEmptyTitle,
                      body: L.of(context).modulesEmptyBody,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(moduleCatalogueProvider);
                      await ref.read(moduleCatalogueProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        if (catalogue.mine.isNotEmpty) ...[
                          _SectionTitle(L.of(context).modulesMine),
                          for (final module in catalogue.mine)
                            _ModuleTile(
                              module: module,
                              busy: _busy.contains(module.slug),
                              onToggle: () => _toggle(module),
                            ),
                        ],
                        if (catalogue.recommended.isNotEmpty) ...[
                          _SectionTitle(
                            L.of(context).modulesRecommended,
                            subtitle: L.of(context).modulesRecommendedBy,
                          ),
                          _ModuleCarousel(
                            modules: catalogue.recommended,
                            busy: _busy,
                            onToggle: _toggle,
                          ),
                        ],
                        if (catalogue.popular.isNotEmpty) ...[
                          _SectionTitle(
                            L.of(context).modulesPopular,
                            subtitle: L.of(context).modulesPopularSub,
                          ),
                          for (final module in catalogue.popular)
                            _ModuleTile(
                              module: module,
                              busy: _busy.contains(module.slug),
                              onToggle: () => _toggle(module),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Les recommandations défilent horizontalement — une vitrine, pas une liste.
///
/// Elles sont peu nombreuses et choisies : leur donner la même forme que le
/// reste les noierait dedans, ce qui viderait la recommandation de son sens.
class _ModuleCarousel extends StatelessWidget {
  const _ModuleCarousel({
    required this.modules,
    required this.busy,
    required this.onToggle,
  });

  final List<AppModule> modules;
  final Set<String> busy;
  final Future<void> Function(AppModule) onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: modules.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _ModuleCard(
          module: modules[index],
          busy: busy.contains(modules[index].slug),
          onToggle: () => onToggle(modules[index]),
        ),
      ),
    );
  }
}

/// Une recommandation, dans le langage visuel de l'application.
///
/// La première version posait un dégradé aux couleurs du module et une
/// bordure teintée — une carte de boutique d'applications, pas une carte de
/// Pokou. Elle contredisait les deux règles du système de design : le vert
/// est un VERBE, qui remplit une action et rien d'autre, et le teal est
/// l'encre.
///
/// La surface redevient donc blanche avec un filet, comme partout ailleurs.
/// La couleur du module ne subsiste qu'à un seul endroit : la pastille de
/// son icône. C'est assez pour le reconnaître d'un coup d'œil dans une
/// grille, et assez peu pour que dix modules côte à côte ne ressemblent pas
/// à un nuancier.
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.busy,
    required this.onToggle,
  });

  final AppModule module;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 218,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ModuleBadge(module: module, size: 40),
          const SizedBox(height: 12),
          Text(
            module.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              module.tagline,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onToggle,
              style: FilledButton.styleFrom(
                // LE vert d'action, et non la couleur du module : activer
                // est un verbe, et tous les verbes de l'application portent
                // la même couleur. Un bouton par teinte apprendrait à
                // l'utilisateur que la couleur ne veut rien dire.
                //
                // Le teal profond plutôt que le vert vif : c'est celui des
                // écrans payants (voir PayBar), et cette page est une
                // vitrine de modules dont plusieurs se paient.
                backgroundColor: AppColors.accentPrimaryDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(L.of(context).modulesEnable),
            ),
          ),
        ],
      ),
    );
  }
}

/// La pastille d'icône — vert plein, icône blanche, pour tous les modules.
///
/// Une teinte par module donnait à la galerie l'allure d'un nuancier : dix
/// pastilles de dix couleurs côte à côte, et plus aucune ne signifiait quoi
/// que ce soit. La forme distingue déjà chaque module — c'est l'ICÔNE qui
/// l'identifie, pas sa couleur.
///
/// Le vert est celui de l'application, le même que sur les boutons et le
/// reste de la marque. `accent_color` continue d'exister côté serveur et
/// reste lu par le modèle : un module peut encore porter sa couleur là où
/// elle dirait quelque chose (l'écran du module lui-même), sans la répandre
/// dans une liste.
class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({required this.module, this.size = 42});

  final AppModule module;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Le teal PROFOND de la marque, pas le vert vif. Une grille de
        // pastilles vives tire l'œil vers les icônes au lieu des noms, et
        // c'est le nom qui dit ce que fait un module.
        color: AppColors.accentPrimaryDark,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(module.icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.busy,
    required this.onToggle,
  });

  final AppModule module;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _ModuleBadge(module: module),
      title: Text(
        module.name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        module.tagline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          height: 1.3,
        ),
      ),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          // Un interrupteur et non un bouton « Activer » / « Désactiver » :
          // l'état se lit d'un coup d'œil, sans avoir à comprendre si le
          // libellé décrit l'état courant ou l'action à venir — la confusion
          // la plus courante sur ce genre de liste.
          : Switch(
              value: module.isActivated,
              // Le même teal que la pastille : un interrupteur par teinte
              // redonnerait à la liste l'aspect de nuancier qu'on vient d'en
              // retirer.
              activeThumbColor: AppColors.accentPrimaryDark,
              onChanged: (_) => onToggle(),
            ),
      // Un module ACTIVÉ s'ouvre ; un module qu'on n'a pas encore pris
      // présente sa fiche. C'est le geste qu'on attend dans chaque cas :
      // on ne relit pas la description d'une application qu'on utilise déjà.
      onTap: () {
        if (module.isActivated) {
          final builder = moduleScreenFor(module.slug);
          if (builder != null) {
            Navigator.of(context).push(MaterialPageRoute(builder: builder));
            return;
          }
          // Activé, mais l'écran n'existe pas dans cette version. On le DIT :
          // ouvrir une page vide laisserait croire à une panne, et rouvrir
          // la fiche descriptive donnerait l'impression que l'appui n'a rien
          // fait.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(L.of(context).modulesComingSoon(module.name)),
            ),
          );
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.bottomSheet,
          ),
          builder: (sheetContext) => _ModuleDetails(
            module: module,
            onToggle: () {
              Navigator.pop(sheetContext);
              onToggle();
            },
          ),
        );
      },
    );
  }
}

/// La description longue, à la demande.
///
/// Elle n'est pas dans la liste parce qu'elle y rendrait chaque ligne
/// illisible ; mais elle doit exister quelque part : personne n'active une
/// fonctionnalité dont il ne comprend pas ce qu'elle fera de ses données ou
/// de son temps.
class _ModuleDetails extends StatelessWidget {
  const _ModuleDetails({required this.module, required this.onToggle});

  final AppModule module;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ModuleBadge(module: module, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        module.tagline,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              module.description,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            if (module.userCount > 0) ...[
              const SizedBox(height: 14),
              Text(
                L.of(context).modulesUserCount(module.userCount),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onToggle,
                style: FilledButton.styleFrom(
                  // Désactiver n'est pas une action « verte » : c'est un
                  // retrait, et le lui donner la même couleur qu'activer
                  // rendrait les deux indistinguables au premier coup d'œil.
                  backgroundColor: module.isActivated
                      ? AppColors.surfaceElevated
                      : AppColors.accentPrimaryDark,
                  foregroundColor: module.isActivated
                      ? AppColors.textPrimary
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  module.isActivated
                      ? L.of(context).modulesDisable
                      : L.of(context).modulesEnable,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
