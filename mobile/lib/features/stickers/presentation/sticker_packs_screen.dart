import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/media/image_cropper.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/sticker_models.dart';
import 'sticker_image.dart';
import 'sticker_providers.dart';

/// Gérer ses packs : ceux qu'on a, ceux qu'on peut ajouter, et les siens.
///
/// ── Retirer n'est pas supprimer ────────────────────────────────────────
///
/// Retirer un pack officiel le sort de SA liste ; le pack continue
/// d'exister pour les autres. Supprimer n'existe que pour un pack
/// PERSONNEL, celui qu'on a fabriqué soi-même — et là, ça détruit vraiment
/// les images. Les deux gestes portent donc deux mots différents et deux
/// icônes différentes, parce que les confondre ferait perdre un travail
/// qu'on ne peut pas refaire.
class StickerPacksScreen extends ConsumerStatefulWidget {
  const StickerPacksScreen({super.key, this.startWithCreation = false});

  final bool startWithCreation;

  @override
  ConsumerState<StickerPacksScreen> createState() => _StickerPacksScreenState();
}

class _StickerPacksScreenState extends ConsumerState<StickerPacksScreen> {
  bool _busy = false;

  L get _l => L.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.startWithCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _createFromPhoto();
      });
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Fabriquer un sticker à partir d'une photo.
  ///
  /// Le recadrage CARRÉ n'est pas une coquetterie : un sticker s'affiche
  /// dans une grille et dans une bulle sans cadre, toutes deux carrées.
  /// Une photo en 4:3 s'y ferait rogner arbitrairement, souvent en coupant
  /// le sujet — le même défaut que les avatars avaient avant d'être
  /// recadrés ici aussi.
  Future<void> _createFromPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await cropSquareImage(context, bytes);
    if (cropped == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(stickerRepositoryProvider);
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: cropped,
            // Le recadrage rend du PNG : annoncer le type réel, pas celui
            // déduit du nom d'origine.
            filename: '${picked.name}.png',
            mimeType: 'image/png',
            // STICKER et non IMAGE : le serveur n'accepte qu'une image sous
            // ce type, et c'est ce qui l'empêchera d'atterrir dans les
            // « photos » de la conversation.
            messageType: 'STICKER',
          );

      // Son pack personnel, créé à la volée s'il n'en a pas encore. Lui
      // demander de le nommer d'abord ajouterait une étape à un geste qui
      // doit en compter le moins possible.
      final packs = ref.read(stickerPanelProvider).packs;
      final perso = packs.where((p) => p.isPersonal).firstOrNull;
      final cible = perso ?? await repo.createPack(_l.stickerMyPackName);

      await repo.addToPack(packId: cible.id, mediaAssetId: uploaded.id);
      await ref.read(stickerPanelProvider.notifier).load();
      _toast(_l.stickerCreated);
    } on ApiException catch (error) {
      // 409 = le pack est plein. Le dire avec le mot juste plutôt qu'avec
      // un code : la limite est une décision, pas une panne.
      _toast(error.statusCode == 409 ? _l.stickerLimitReached : error.message);
    } catch (_) {
      _toast(_l.stickerSendFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(StickerPack pack) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(pack.name),
        content: Text(_l.stickerPackDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(dialogContext).actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              _l.stickerPackDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(stickerPanelProvider.notifier).deletePack(pack.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stickerPanelProvider);
    final store = ref.watch(stickerStoreProvider);
    final installedIds = state.packs.map((p) => p.id).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(_l.stickerPacksTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.add_photo_alternate_outlined,
              color: AppColors.accentPrimaryDark,
            ),
            title: Text(_l.stickerCreateFromPhoto),
            enabled: !_busy,
            onTap: _busy ? null : _createFromPhoto,
            trailing: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const Divider(height: 1),

          // Ses packs à lui, en premier : c'est ce qu'il vient gérer. La
          // liste se réordonne au doigt — c'est cet ordre-là qui décide de
          // celui des onglets du panneau, donc de ce qu'il a sous le pouce.
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) => ref
                .read(stickerPanelProvider.notifier)
                .reorder(oldIndex, newIndex),
            children: [
              for (final (index, pack) in state.packs.indexed)
                _PackTile(
                  // La clé porte l'identifiant du pack, pas sa position :
                  // réordonner change les positions, et Flutter perdrait
                  // la trace des lignes.
                  key: ValueKey(pack.id),
                  pack: pack,
                  // Une poignée EXPLICITE, et non le glissement long par
                  // défaut : sans elle, un appui un peu appuyé sur une
                  // ligne la déplacerait sans qu'on l'ait voulu.
                  leadingHandle: ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle,
                      color: AppColors.chatIconMuted,
                    ),
                  ),
                  trailing: pack.isPersonal
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          tooltip: _l.stickerPackDelete,
                          onPressed: () => _confirmDelete(pack),
                        )
                      : TextButton(
                          onPressed: () => ref
                              .read(stickerPanelProvider.notifier)
                              .uninstall(pack.id),
                          child: Text(_l.stickerPackRemove),
                        ),
                ),
            ],
          ),

          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _l.stickerBrowsePacks,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.chatIconMuted,
              ),
            ),
          ),
          store.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(_l.stickerStoreEmpty)),
            ),
            data: (packs) {
              final disponibles = packs
                  .where((p) => !installedIds.contains(p.id))
                  .toList();
              if (disponibles.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      _l.stickerStoreEmpty,
                      style: TextStyle(color: AppColors.chatIconMuted),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final pack in disponibles)
                    _PackTile(
                      pack: pack,
                      trailing: TextButton(
                        onPressed: () => ref
                            .read(stickerPanelProvider.notifier)
                            .install(pack.id),
                        child: Text(_l.stickerPackAdd),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    super.key,
    required this.pack,
    required this.trailing,
    this.leadingHandle,
  });

  final StickerPack pack;
  final Widget trailing;

  /// La poignée de déplacement — absente pour les packs du catalogue, qu'on
  /// n'a pas encore installés et qui n'ont donc pas de place à eux.
  final Widget? leadingHandle;

  @override
  Widget build(BuildContext context) {
    final thumbnail = pack.thumbnailMediaId;
    final vignette = SizedBox(
      width: 40,
      height: 40,
      child: thumbnail == null
          ? Icon(Icons.image_outlined, color: AppColors.chatIconMuted)
          : StickerImage(mediaId: thumbnail, size: 40),
    );
    return ListTile(
      leading: leadingHandle == null
          ? vignette
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [leadingHandle!, const SizedBox(width: 8), vignette],
            ),
      title: Text(pack.name),
      subtitle: Text(
        [
          if (pack.authorName != null && pack.authorName!.isNotEmpty)
            pack.authorName!,
          '${pack.stickerCount}',
        ].join(' · '),
      ),
      trailing: trailing,
    );
  }
}
