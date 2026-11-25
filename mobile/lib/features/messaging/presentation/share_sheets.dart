import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/pokou_location.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../core/widgets/pokou_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/legal_screen.dart';
import '../../contacts/presentation/contacts_controller.dart';

/// Une fiche à partager : un nom et un numéro.
typedef SharedContactCard = ({String displayName, String phone});

/// Une position prête à partir.
typedef SharedPlace = ({double latitude, double longitude, String? label});

/// « Partager ce contact ? » — la fenêtre de confirmation, mot pour mot ce
/// que l'équipe a demandé. Le numéro partagé est celui d'une autre
/// personne : on le rappelle AVANT l'envoi, pas après.
///
/// `true` seulement sur « Partager ».
Future<bool> confirmShareContact(BuildContext context) async {
  final l = L.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.chatXShareContactTitle),
          content: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: l.chatXShareContactBody),
                const TextSpan(text: ' '),
                TextSpan(
                  text: l.chatXLearnMore,
                  style: TextStyle(
                    color: AppColors.accentPrimaryDark,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => Navigator.of(dialogContext).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const LegalScreen(name: 'confidentialite'),
                      ),
                    ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.chatXShareAction),
            ),
          ],
        ),
      ) ??
      false;
}

/// Choisir la fiche à partager : le carnet synchronisé (les comptes Pokou
/// en tête, marqués), ou tout le répertoire du téléphone.
Future<SharedContactCard?> pickContactToShare(
  BuildContext context,
  WidgetRef ref,
) {
  return showPokouSheet<SharedContactCard>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.8,
      child: const ContactSharePicker(),
    ),
  );
}

/// Le contenu de la feuille de choix — exposé pour les tests.
class ContactSharePicker extends ConsumerStatefulWidget {
  const ContactSharePicker({super.key});

  @override
  ConsumerState<ContactSharePicker> createState() => _ContactSharePickerState();
}

class _ContactSharePickerState extends ConsumerState<ContactSharePicker> {
  final _search = TextEditingController();

  /// Le répertoire complet du téléphone, chargé à la demande.
  List<SharedContactCard>? _device;
  bool _loadingDevice = false;
  bool _deviceRefused = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadDevice() async {
    setState(() => _loadingDevice = true);
    final service = ref.read(deviceContactsServiceProvider);
    try {
      if (!await service.hasPermission()) {
        if (mounted) {
          setState(() {
            _deviceRefused = true;
            _loadingDevice = false;
          });
        }
        return;
      }
      final mine = ref.read(authControllerProvider).user?.phone ?? '';
      final entries = await service.readAll(myPhoneE164: mine);
      final seen = <String>{};
      final cards =
          <SharedContactCard>[
            for (final entry in entries)
              if (seen.add(entry.phone))
                (displayName: entry.name, phone: entry.phone),
          ]..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );
      if (mounted) {
        setState(() {
          _device = cards;
          _loadingDevice = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceRefused = true;
          _loadingDevice = false;
        });
      }
    }
  }

  bool _matches(SharedContactCard card, String needle) =>
      needle.isEmpty ||
      card.displayName.toLowerCase().contains(needle) ||
      card.phone.replaceAll(' ', '').contains(needle.replaceAll(' ', ''));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final needle = _search.text.trim().toLowerCase();
    final book = ref.watch(contactsProvider).valueOrNull ?? const [];
    final myId = ref.watch(authControllerProvider).user?.id;
    final fromBook =
        [
          for (final contact in book)
            if (contact.contactUserId != myId)
              (
                card: (displayName: contact.displayName, phone: contact.phone),
                onPokou: contact.isRegistered,
              ),
        ]..sort((a, b) {
          if (a.onPokou != b.onPokou) return a.onPokou ? -1 : 1;
          return a.card.displayName.toLowerCase().compareTo(
            b.card.displayName.toLowerCase(),
          );
        });
    final device = _device;
    final rows = device == null
        ? [
            for (final entry in fromBook)
              if (_matches(entry.card, needle)) entry,
          ]
        : [
            for (final card in device)
              if (_matches(card, needle)) (card: card, onPokou: false),
          ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.chatXShareContactPick,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: l.actionClose,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l.chatXShareContactSearch,
              border: const OutlineInputBorder(borderRadius: AppRadius.card),
              isDense: true,
            ),
          ),
        ),
        if (device == null)
          ListTile(
            leading: _loadingDevice
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.contacts_outlined),
            title: Text(l.chatXShareFromPhoneBook),
            subtitle: _deviceRefused
                ? Text(l.chatXShareFromPhoneBookRefused)
                : null,
            onTap: _loadingDevice ? null : _loadDevice,
          ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    l.chatXShareContactEmpty,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceElevated,
                        child: Icon(
                          Icons.person,
                          color: AppColors.accentPrimaryDark,
                        ),
                      ),
                      title: Text(row.card.displayName),
                      subtitle: Text(row.card.phone),
                      trailing: row.onPokou
                          ? Text(
                              l.chatXOnPokou,
                              style: TextStyle(
                                color: AppColors.accentPrimaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, row.card),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Position actuelle : demandée proprement (voir pokou_location.dart), puis
/// nommée (« Bè, Lomé ») et montrée AVANT l'envoi — une position part
/// rarement par erreur deux fois.
Future<SharedPlace?> pickLocationToShare(
  BuildContext context,
  WidgetRef ref,
) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final api = ref.read(apiClientProvider);
  try {
    final position = await obtainPosition(context);
    if (position == null || !context.mounted) return null;
    final label = await placeLabel(api, position.latitude, position.longitude);
    if (!context.mounted) return null;
    final send = await showPokouSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.chatActionGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.chatXLocationCurrent,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          label ?? l.chatXLocationNearYou,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l.chatXLocationEncrypted,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.send),
                label: Text(l.chatXLocationSend),
              ),
            ],
          ),
        ),
      ),
    );
    if (send != true) return null;
    return (
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
    );
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text(l.chatXLocationFailed)));
    return null;
  }
}
