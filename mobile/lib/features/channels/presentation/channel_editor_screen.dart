import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../data/channel_model.dart';
import 'channel_controller.dart';
import '../../../core/widgets/media_image.dart';

class ChannelEditorScreen extends ConsumerStatefulWidget {
  const ChannelEditorScreen({super.key, this.channel});

  final PokouChannel? channel;

  @override
  ConsumerState<ChannelEditorScreen> createState() =>
      _ChannelEditorScreenState();
}

class _ChannelEditorScreenState extends ConsumerState<ChannelEditorScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _saving = false;

  /// Image de la chaîne. `_avatar` porte celle affichée, `_avatarChanged` dit
  /// s'il faut l'envoyer : à la création il n'y a rien à effacer, et en
  /// modification un enregistrement qui ne touche pas à l'image ne doit pas
  /// la réécrire (ni la supprimer).
  MediaMeta? _avatar;
  bool _avatarChanged = false;

  /// Privée ou publique — choisi À LA CRÉATION seulement.
  ///
  /// Une chaîne publique qui devient privée du jour au lendemain ferait
  /// disparaître un fil que des gens suivaient, sans qu'ils comprennent
  /// pourquoi. Et l'inverse — privée qui devient publique — exposerait d'un
  /// coup tout ce qui y a été publié en confiance. Les deux méritent une
  /// décision explicite et un avertissement, pas un interrupteur dans un
  /// formulaire de renommage.
  bool _isPrivate = false;
  bool _uploading = false;

  bool get _isEditing => widget.channel != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.channel?.description ?? '',
    );
    _avatar = widget.channel?.avatar;
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: bytes,
            filename: picked.name,
            mimeType: lookupMimeType(picked.name) ?? 'image/jpeg',
            messageType: 'IMAGE',
          );
      if (mounted) {
        setState(() {
          _avatar = MediaMeta(
            id: uploaded.id,
            mimeType: uploaded.mimeType,
            sizeBytes: uploaded.sizeBytes,
            originalFilename: picked.name,
          );
          _avatarChanged = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).marketImageFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).channelNameRequired)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(channelRepositoryProvider);
      final description = _descriptionController.text.trim();
      final PokouChannel channel;
      if (_isEditing) {
        channel = await repository.updateChannel(
          channelId: widget.channel!.id,
          name: name,
          description: description,
          avatarMediaId: _avatarChanged ? _avatar?.id : null,
          clearAvatar: _avatarChanged && _avatar == null,
        );
      } else {
        final created = await repository.create(
          name: name,
          description: description,
          isPrivate: _isPrivate,
        );
        // L'image ne peut être posée qu'après la création : la chaîne n'a
        // pas d'identifiant avant.
        channel = (_avatarChanged && _avatar != null)
            ? await repository.updateChannel(
                channelId: created.id,
                avatarMediaId: _avatar!.id,
              )
            : created;
      }
      if (mounted) Navigator.of(context).pop(channel);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).channelSaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const PokouBackButton(),
        title: Text(
          _isEditing
              ? L.of(context).channelEditTitle
              : L.of(context).channelNewTitle,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: _uploading ? null : _pickAvatar,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 88,
                      height: 88,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentPrimaryLight,
                      ),
                      child: _uploading
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : _avatar == null
                          ? const Icon(
                              Icons.add_a_photo_outlined,
                              size: 34,
                              color: Colors.white,
                            )
                          : _AvatarPreview(media: _avatar!),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _uploading ? null : _pickAvatar,
                    child: Text(
                      _avatar == null
                          ? L.of(context).channelAddImage
                          : L.of(context).channelChangeImage,
                    ),
                  ),
                  if (_avatar != null)
                    TextButton(
                      onPressed: _uploading
                          ? null
                          : () => setState(() {
                              _avatar = null;
                              _avatarChanged = true;
                            }),
                      child: Text(
                        L.of(context).channelRemoveImage,
                        style: const TextStyle(color: AppColors.semanticError),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              maxLength: 255,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: L.of(context).channelNameLabel,
                hintText: L.of(context).channelNameHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: 2000,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: L.of(context).channelDescriptionLabel,
                hintText: L.of(context).channelDescriptionHint,
              ),
            ),
            // Le choix n'apparaît qu'à la CRÉATION : voir `_isPrivate`.
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  L.of(context).channelPrivateLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  L.of(context).channelPrivateBody,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              // Bloqué pendant un téléversement : enregistrer maintenant
              // sauverait la chaîne sans l'image en cours d'envoi.
              onPressed: (_saving || _uploading) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isEditing
                    ? L.of(context).channelSaveChanges
                    : L.of(context).channelCreateAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu de l'image de chaîne — servie par l'API authentifiée, donc résolue
/// en fichier local comme les autres médias.
class _AvatarPreview extends ConsumerWidget {
  const _AvatarPreview({required this.media});

  final MediaMeta media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 88,
      height: 88,
      child: MediaImage.meta(
        media,
        decodeWidth: 88,
        placeholder: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
