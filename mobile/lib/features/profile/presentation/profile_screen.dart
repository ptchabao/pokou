import 'dart:async';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../marketplace/presentation/marketplace_controller.dart';
import '../../marketplace/presentation/seller_verification_screen.dart';
import 'language_screen.dart';
import 'theme_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/media/image_cropper.dart';
import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../core/security/app_lock.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/minou_repository.dart';
import '../../chat/presentation/chat_controller.dart'
    show kNoMonitor, minouStatusProvider;
import '../../settings/presentation/backup_screens.dart';
import '../../settings/presentation/app_lock_screen.dart';
import '../../settings/presentation/change_number_screen.dart';
import '../../settings/presentation/delete_account_screen.dart';
import '../../settings/presentation/devices_screen.dart';
import '../../settings/presentation/notifications_settings_screen.dart';
import '../../settings/presentation/privacy_settings_screen.dart';
import '../../settings/presentation/storage_settings_screen.dart';
import '../../status/presentation/status_privacy_screen.dart';
import '../data/profile_repository.dart';
import '../../../core/widgets/pokou_context_menu.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(apiClient: ref.watch(apiClientProvider));
});

// Filet fin gris 6% — pas de Divider() plein qui traverse l'écran bord à
// bord ; un vrai séparateur de liste "groupée" reste en retrait des bords.
const _hairline = Color(0x0F000000);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loading = false;
  bool _uploadingAvatar = false;
  String? _fullName;
  String? _about;
  MediaMeta? _avatar;
  bool _isVerified = false;
  bool _isCertificationPending = false;
  bool _isCertifiedSeller = false;
  DateTime? _certifiedSellerUntil;

  @override
  void initState() {
    super.initState();
    final cachedUser = ref.read(authControllerProvider).user;
    _fullName = cachedUser?.fullName;
    _about = cachedUser?.about;
    _avatar = cachedUser?.avatar;
    _isVerified = cachedUser?.isVerified ?? false;
    _isCertificationPending = cachedUser?.isCertificationPending ?? false;
    _isCertifiedSeller = cachedUser?.isCertifiedSeller ?? false;
    _certifiedSellerUntil = cachedUser?.certifiedSellerUntil;
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ref.read(profileRepositoryProvider).getMine();
      if (!mounted) return;
      ref
          .read(authControllerProvider.notifier)
          .setCertificationStatus(
            isVerified: user.isVerified,
            isCertificationPending: user.isCertificationPending,
            isCertifiedSeller: user.isCertifiedSeller,
            certifiedSellerUntil: user.certifiedSellerUntil,
          );
      setState(() {
        _fullName = user.fullName;
        _about = user.about;
        _avatar = user.avatar;
        _isVerified = user.isVerified;
        _isCertificationPending = user.isCertificationPending;
        _isCertifiedSeller = user.isCertifiedSeller;
        _certifiedSellerUntil = user.certifiedSellerUntil;
      });
    } catch (_) {
      // Best-effort — l'écran reste utilisable avec les infos déjà connues
      // (numéro de téléphone via authControllerProvider).
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _changeAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).profileGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: AppColors.accentPrimaryDark,
              ),
              title: Text(L.of(context).profileCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: ref.read(appSettingsProvider).imageUploadQuality,
    );
    if (picked == null || !mounted) return;

    // Recadrage carré avant l'envoi : un portrait pris en 4:3 serait sinon
    // rogné arbitrairement à l'affichage, souvent en coupant le visage.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await cropSquareImage(context, bytes);
    if (cropped == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uploaded = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: cropped,
            // Le recadrage rend du PNG : annoncer le type réel plutôt que
            // celui déduit du nom du fichier d'origine.
            filename: '${picked.name}.png',
            mimeType: 'image/png',
            messageType: 'IMAGE',
          );
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateMine(avatarMediaId: uploaded.id);
      if (mounted) setState(() => _avatar = updated.avatar);
      // L'accueil, le menu Plus et les discussions montrent ma photo depuis
      // l'état de session : sans cette relecture, ils gardaient l'ancienne
      // jusqu'au redémarrage de l'application.
      unawaited(ref.read(authControllerProvider.notifier).reloadProfile());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).profileAvatarFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: _fullName ?? '');
    final aboutController = TextEditingController(text: _about ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L.of(context).profileEdit,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: nameController,
              decoration: InputDecoration(
                hintText: L.of(context).profileFullName,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: aboutController,
              maxLength: 140,
              decoration: InputDecoration(hintText: L.of(context).profileAbout),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: Text(L.of(context).actionSave),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;

    try {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateMine(
            fullName: nameController.text.trim().isEmpty
                ? null
                : nameController.text.trim(),
            about: aboutController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _fullName = updated.fullName;
          _about = updated.about;
        });
      }
      unawaited(ref.read(authControllerProvider.notifier).reloadProfile());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).profileUpdateFailed)),
        );
      }
    }
  }

  Future<void> _openMahizu() async {
    MinouStatus status;
    try {
      // /minou/status et non la liste des moniteurs POSSÉDÉS : on peut être
      // destinataire des alertes d'un moniteur sans en posséder aucun. Même
      // aiguillage que la tuile épinglée des contacts — deux entrées vers
      // Minou ne doivent pas mener à deux endroits différents.
      status = await ref.read(minouStatusProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(L.of(context).errorNetwork)));
      }
      return;
    }
    if (!mounted) return;

    final monitors = status.monitors;
    if (status.mode == MinouMode.messaging || monitors.isEmpty) {
      context.push('/chat/$kNoMonitor', extra: L.of(context).navBaba);
      return;
    }
    if (monitors.length == 1) {
      context.push('/chat/${monitors.first.id}', extra: monitors.first.name);
      return;
    }

    final chosen = await showModalBottomSheet<MinouMonitor>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.of(context).profileChooseMonitor,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            for (final monitor in monitors)
              ListTile(
                leading: const AssistantOrb(size: 32),
                title: Text(monitor.name),
                subtitle: Text(
                  monitor.intention,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, monitor),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      context.push('/chat/${chosen.id}', extra: chosen.name);
    }
  }

  /// Les écrans de réglages sont poussés sur le Navigator comme le reste des
  /// écrans de détail de l'app (conversation, groupe, appel) — go_router ne
  /// porte que les routes d'authentification et l'ancien chat Mahizu.
  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout() async {
    // Avant la déconnexion : un code de verrouillage oublié laisserait sinon
    // l'app verrouillée sur l'écran de connexion (voir app_lock.dart).
    await ref.read(appLockProvider.notifier).forgetOnLogout();
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/welcome');
  }

  Future<void> _verifyAccount() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SellerVerificationScreen()),
    );
    if (submitted == true) {
      if (mounted) setState(() => _isCertificationPending = true);
      ref
          .read(authControllerProvider.notifier)
          .setCertificationStatus(isCertificationPending: true);
      ref.invalidate(mySellerCertificationProvider);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider).user;
    final phone = authUser?.phone;
    final isVerified = _isVerified || (authUser?.isVerified ?? false);
    final isPending =
        _isCertificationPending || (authUser?.isCertificationPending ?? false);
    final sellerUntil = _certifiedSellerUntil;
    final lockState = ref.watch(appLockProvider);
    final settings = ref.watch(appSettingsProvider);
    final minouAsync = ref.watch(minouStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        child: Column(
                          children: [
                            _buildAvatar(),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _editProfile,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        (_fullName == null ||
                                                _fullName!.trim().isEmpty)
                                            ? (phone ?? L.of(context).navYou)
                                            : _fullName!,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) ...[
                                      const SizedBox(width: 6),
                                      const VerifiedBadge(size: 18),
                                    ],
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_about != null &&
                                _about!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _about!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 12,
                                  color: AppColors.accentPrimaryDark,
                                ),
                                const SizedBox(width: 4),
                                // Formulation volontairement honnête : il n'y a
                                // pas de chiffrement de bout en bout dans
                                // Pokou aujourd'hui — l'identité est vérifiée
                                // par OTP téléphone et la connexion passe en
                                // TLS, rien de plus, rien de moins.
                                Text(
                                  L.of(context).profileVerifiedPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.accentPrimaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _MahizuCard(
                          // Le sous-titre dit ce qu'on va trouver derrière, et
                          // le tap y mène : même source pour les deux (voir
                          // _openMahizu). « Chat généraliste configuré »
                          // décrivait l'ancien comportement — c'est la vraie
                          // messagerie Minou qui répond désormais.
                          subtitle: minouAsync.when(
                            data: (status) {
                              final count = status.monitors.length;
                              if (status.mode == MinouMode.messaging ||
                                  count == 0) {
                                return L.of(context).profileBabaMessaging;
                              }
                              return L.of(context).profileMonitorAlerts(count);
                            },
                            loading: () => L.of(context).commonLoading,
                            error: (_, _) => L.of(context).profileBabaAssistant,
                          ),
                          onTap: _openMahizu,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _SettingsGroup(
                        title: L.of(context).profileMyAccount,
                        children: [
                          // ── Vérifier mon compte ───────────────────────
                          //
                          // L'écran existait déjà, mais uniquement derrière le
                          // menu « ⋮ » de la Marketplace, sous le libellé
                          // « Devenir vendeur vérifié ». Autrement dit : il
                          // fallait déjà se penser vendeur pour le trouver.
                          //
                          // Deux certifications distinctes (voir
                          // api/app/utils/identity.py) : le ✓ d'IDENTITÉ,
                          // accordé par l'équipe, et le badge VENDEUR, que
                          // pose l'approbation du dossier ouvert ici. Le
                          // menu suit le second : il ne proposait « Vérifier
                          // mon compte » qu'en l'absence du premier, et un
                          // vendeur approuvé se le voyait encore offrir.
                          if (isVerified)
                            _SettingsRow(
                              icon: Icons.verified,
                              label: L.of(context).profileCertificationActive,
                              subtitle: L
                                  .of(context)
                                  .profileCertificationActiveBody,
                              onTap: null,
                            ),
                          if (_isCertifiedSeller)
                            _SettingsRow(
                              icon: Icons.storefront_rounded,
                              label: L.of(context).profileSellerCertified,
                              subtitle: sellerUntil == null
                                  ? null
                                  : L
                                        .of(context)
                                        .profileSellerCertifiedUntil(
                                          DateFormat.yMMMMd(
                                            Localizations.localeOf(
                                              context,
                                            ).toLanguageTag(),
                                          ).format(sellerUntil.toLocal()),
                                        ),
                              onTap: null,
                            )
                          else if (isPending)
                            _SettingsRow(
                              icon: Icons.hourglass_top_rounded,
                              label: L.of(context).profileCertificationPending,
                              subtitle: L
                                  .of(context)
                                  .profileCertificationPendingBody,
                              onTap: null,
                            )
                          else
                            _SettingsRow(
                              icon: Icons.verified_outlined,
                              label: L.of(context).profileVerifyAccount,
                              subtitle: L.of(context).profileVerifyAccountBody,
                              onTap: _verifyAccount,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsGroup(
                        title: L.of(context).profilePrivacySecurity,
                        children: [
                          _SettingsRow(
                            icon: Icons.lock_outline,
                            label: L.of(context).profileConnection,
                            trailing: Text(
                              L.of(context).profileEncryptedTls,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          // Le centre de contrôle : les six règles qui
                          // décident de ce que les autres apprennent. Placé
                          // AVANT la visibilité des statuts, qui n'en est
                          // qu'un cas particulier — et qui garde son écran
                          // dédié parce qu'elle seule accepte une liste
                          // d'exceptions nominatives.
                          _SettingsRow(
                            icon: Icons.lock_person_outlined,
                            label: L.of(context).privacyTitle,
                            subtitle: L.of(context).privacySectionWhoSees,
                            onTap: () => _push(const PrivacySettingsScreen()),
                          ),
                          _SettingsRow(
                            icon: Icons.donut_large_outlined,
                            label: L.of(context).profileStatusVisibility,
                            onTap: () => _push(const StatusPrivacyScreen()),
                          ),
                          _SettingsRow(
                            icon: Icons.pin_outlined,
                            label: L.of(context).lockTitle,
                            trailing: Row(
                              children: [
                                Text(
                                  lockState.enabled
                                      ? L.of(context).commonEnabled
                                      : L.of(context).commonDisabled,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                            onTap: () => _push(const AppLockSettingsScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SettingsGroup(
                        title: L.of(context).profileSystemPrefs,
                        children: [
                          _SettingsRow(
                            icon: Icons.notifications_outlined,
                            label: L.of(context).profileNotifications,
                            onTap: () =>
                                _push(const NotificationsSettingsScreen()),
                          ),
                          _SettingsRow(
                            icon: Icons.storage_outlined,
                            label: L.of(context).profileStorage,
                            onTap: () => _push(const StorageSettingsScreen()),
                          ),
                          // Économie de données : un interrupteur sur place
                          // plutôt qu'un écran pour un seul réglage. Il vit
                          // aussi dans « Stockage et données », qui est le
                          // même sujet vu de l'autre bout.
                          _SettingsRow(
                            icon: Icons.signal_cellular_alt,
                            label: L.of(context).profileDataSaver,
                            trailing: Semantics(
                              label: L.of(context).profileDataSaver,
                              child: Switch(
                                value: settings.dataSaver,
                                activeThumbColor: Colors.white,
                                activeTrackColor: AppColors.accentPrimary,
                                onChanged: (value) => ref
                                    .read(appSettingsProvider.notifier)
                                    .setDataSaver(value),
                              ),
                            ),
                          ),
                          // L'apparence juste avant la langue : ce sont les
                          // deux réglages qui changent l'allure de toute
                          // l'application, et on les cherche au même endroit.
                          _SettingsRow(
                            icon: Icons.brightness_6_outlined,
                            label: L.of(context).profileTheme,
                            onTap: () => _push(const ThemeScreen()),
                          ),
                          _SettingsRow(
                            icon: Icons.language,
                            label: L.of(context).profileLanguage,
                            onTap: () => _push(const LanguageScreen()),
                          ),
                          _SettingsRow(
                            icon: Icons.devices_outlined,
                            label: L.of(context).profileDevices,
                            onTap: () => _push(const DevicesScreen()),
                          ),
                          // MSG-12 : la sauvegarde chiffrée des discussions.
                          _SettingsRow(
                            icon: Icons.backup_outlined,
                            label: L.of(context).backupTitle,
                            onTap: () => _push(const BackupSettingsScreen()),
                          ),
                          // REG-4 : garder son compte avec une nouvelle puce.
                          _SettingsRow(
                            icon: Icons.phone_iphone,
                            label: L.of(context).changeNumberTitle,
                            onTap: () => _push(const ChangeNumberScreen()),
                          ),
                          // REG-7 : la suppression du compte, depuis
                          // « Compte et sécurité » (AUTH-06).
                          _SettingsRow(
                            icon: Icons.delete_forever_outlined,
                            label: L.of(context).deleteAccountTitle,
                            onTap: () => _push(const DeleteAccountScreen()),
                          ),
                        ],
                      ),
                      // REG-3 : l'avertissement contre l'hameçonnage.
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.chatAiIconColor.withValues(
                            alpha: 0.10,
                          ),
                          border: Border.all(
                            color: AppColors.chatAiIconColor.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          L.of(context).securityPinWarning,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(
                        child: TextButton(
                          onPressed: _logout,
                          child: Text(
                            L.of(context).profileSignOut,
                            style: TextStyle(
                              color: AppColors.chatIconMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Center(
      child: GestureDetector(
        onTap: _uploadingAvatar ? null : _changeAvatar,
        child: Stack(
          children: [
            ContactAvatar(
              avatar: _avatar,
              displayName: _fullName ?? '',
              size: 80,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentPrimaryDark,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: _uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 12,
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MahizuCard extends StatelessWidget {
  const _MahizuCard({required this.subtitle, required this.onTap});

  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.card,
          boxShadow: AppElevation.card,
        ),
        child: Row(
          children: [
            const AssistantOrb(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L.of(context).profileBabaAssistant,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          color: AppColors.surface,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, thickness: 1, color: _hairline),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// Explication sous le libellé — réservée aux réglages dont le NOM ne
  /// suffit pas à dire ce qu'ils font (« Mode Bouclier » n'évoque rien tant
  /// qu'on n'a pas lu ce qu'il filtre).
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.textMuted,
                        )
                      : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}
