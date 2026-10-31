import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../contacts/presentation/contacts_controller.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';
import 'spark_screen.dart';

/// La bannière « tout va bien ? ».
///
/// Posée en haut des sorties, parce que c'est l'écran qu'on ouvre pendant un
/// rendez-vous. Elle n'apparaît que lorsqu'une vérification est due : une
/// question posée tout le temps cesse d'être lue.
class SparkCheckinBanner extends ConsumerWidget {
  const SparkCheckinBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkinsAsync = ref.watch(sparkCheckinsProvider);

    return checkinsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (checkins) {
        if (checkins.isEmpty) return const SizedBox.shrink();
        final checkin = checkins.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.card,
              border: Border.all(color: sparkAccent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: sparkAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      L.of(context).safetyCheckin,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  // Le délai est dit : personne ne doit découvrir après coup
                  // que ses proches ont été prévenus.
                  L.of(context).safetyCheckinBody,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                ModuleActionButton(
                  label: L.of(context).safetyAllGood,
                  onPressed: () async {
                    await ref
                        .read(sparkRepositoryProvider)
                        .answerCheckin(checkin.id);
                    ref.invalidate(sparkCheckinsProvider);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Le cercle de sécurité, et le Safe Word.
class SparkSafetyScreen extends ConsumerStatefulWidget {
  const SparkSafetyScreen({super.key});

  @override
  ConsumerState<SparkSafetyScreen> createState() => _SparkSafetyScreenState();
}

class _SparkSafetyScreenState extends ConsumerState<SparkSafetyScreen> {
  bool _sending = false;

  /// Déclenche l'alerte. **N'affiche aucune erreur.**
  ///
  /// Le dépôt ne lève jamais non plus : un message d'échec au moment où
  /// quelqu'un déclenche discrètement une alerte le mettrait en danger.
  /// L'écran confirme sobrement, et c'est tout.
  Future<void> _triggerSafeWord() async {
    setState(() => _sending = true);
    double? latitude;
    double? longitude;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }
    } catch (_) {
      // Sans position, l'alerte part quand même : savoir que quelqu'un a
      // appelé à l'aide vaut mieux que ne rien savoir parce qu'on n'a pas
      // pu le situer.
    }
    final notified = await ref
        .read(sparkRepositoryProvider)
        .triggerSafeWord(latitude: latitude, longitude: longitude);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          notified > 0
              ? L.of(context).safetyCircleAlerted
              : L.of(context).safetyNoCircle,
        ),
      ),
    );
  }

  Future<void> _addContact() async {
    final contacts = await ref.read(contactsProvider.future);
    final registered = contacts
        .where(
          (contact) => contact.isRegistered && contact.contactUserId != null,
        )
        .toList();
    if (!mounted) return;
    if (registered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).newChatNoRegisteredContact)),
      );
      return;
    }

    final chosen = await showModuleSheet<int>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ModuleSheetTitle(
            L.of(sheetContext).safetyWhoToAlert,
            subtitle: L.of(sheetContext).safetyWhoToAlertBody,
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: registered.length,
              itemBuilder: (_, index) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(registered[index].displayName),
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(registered[index].contactUserId),
              ),
            ),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(sparkRepositoryProvider).addSafetyContact(chosen);
    ref.invalidate(sparkSafetyContactsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(sparkSafetyContactsProvider);

    return ModuleScaffold(
      title: L.of(context).safetyTitle,
      subtitle: L.of(context).safetySubtitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ModuleCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context).safetyQuietAlert,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  L.of(context).safetyQuietAlertBody,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _triggerSafeWord,
                    style: FilledButton.styleFrom(
                      // La seule action rouge de l'application, et elle le
                      // mérite : c'est un appel à l'aide, pas une action
                      // ordinaire.
                      backgroundColor: sparkAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sheet),
                      ),
                    ),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(L.of(context).safetyTrigger),
                  ),
                ),
              ],
            ),
          ),
          ModuleSectionTitle(
            L.of(context).safetyMyCircle,
            subtitle: L.of(context).safetyThreeEnough,
          ),
          contactsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (contacts) {
              if (contacts.isEmpty) {
                return Text(
                  L.of(context).safetyNobodyYet,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                children: [
                  for (final contact in contacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ModuleCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            ModuleBadge(
                              icon: Icons.shield,
                              color: AppColors.accentPrimaryDark,
                              size: 38,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                contact.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                await ref
                                    .read(sparkRepositoryProvider)
                                    .removeSafetyContact(contact.id);
                                ref.invalidate(sparkSafetyContactsProvider);
                              },
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textMuted,
                              ),

                              tooltip: L.of(context).actionClose,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          ModuleQuietButton(
            label: L.of(context).safetyAddSomeone,
            onPressed: _addContact,
          ),
        ],
      ),
    );
  }
}
