import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/widgets/contact_avatar.dart';
import '../../contacts/presentation/discussions_controller.dart';
import 'settings_widgets.dart';

/// La place totale et libre du téléphone (canal natif, Android). `null`
/// ailleurs — iOS, web, tests : la jauge montre alors Pokou seul.
Future<({int total, int free})?> _diskSpace() async {
  try {
    final raw = await const MethodChannel(
      'com.pokou.pokou/storage',
    ).invokeMapMethod<String, dynamic>('diskSpace');
    final total = raw?['total'];
    final free = raw?['free'];
    if (total is! int || free is! int || total <= 0) return null;
    return (total: total, free: free);
  } catch (_) {
    return null;
  }
}

/// Profil > Stockage et données. Remplace l'ancien « vider le cache » à
/// l'aveugle (un simple SnackBar) : on montre d'abord ce que le cache
/// contient, puis on propose de le vider.
class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() =>
      _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  MediaCacheStats? _stats;
  bool _busy = false;

  /// REG-2 : la place prise par discussion (clé → octets), et le nombre de
  /// fichiers de plus de 5 Mo.
  Map<String, int> _byDiscussion = const {};
  int _bigFiles = 0;

  /// Les médias de chaque discussion, pour les libérer d'un geste.
  Map<String, Set<int>> _idsByDiscussion = const {};
  Set<int> _bigIds = const {};
  int _bigBytes = 0;
  ({int total, int free})? _disk;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final media = ref.read(mediaRepositoryProvider);
      final stats = await media.cacheStats();
      final sizes = await media.cacheSizesByMedia();
      final me = ref.read(authControllerProvider).user?.id;
      final owners = me == null
          ? const <int, String>{}
          : await ref.read(pokouMessageStoreProvider).mediaOwners(me);
      final byDiscussion = <String, int>{};
      final idsByDiscussion = <String, Set<int>>{};
      sizes.forEach((id, bytes) {
        final key = owners[id] ?? 'other';
        byDiscussion[key] = (byDiscussion[key] ?? 0) + bytes;
        (idsByDiscussion[key] ??= <int>{}).add(id);
      });
      final disk = await _diskSpace();
      if (mounted) {
        setState(() {
          _stats = stats;
          _byDiscussion = byDiscussion;
          _idsByDiscussion = idsByDiscussion;
          _bigIds = {
            for (final entry in sizes.entries)
              if (entry.value > 5 * 1024 * 1024) entry.key,
          };
          _bigFiles = _bigIds.length;
          _bigBytes = sizes.entries
              .where((entry) => _bigIds.contains(entry.key))
              .fold(0, (sum, entry) => sum + entry.value);
          _disk = disk;
        });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _stats = const MediaCacheStats(fileCount: 0, totalBytes: 0),
        );
    }
  }

  /// Libère les médias en cache d'une discussion (ou les gros fichiers),
  /// après confirmation : ils se retéléchargeront si on les rouvre.
  Future<void> _free(String label, Set<int> ids, int bytes) async {
    final l = L.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.storageFreeBody,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(l.storageFree(formatBytes(bytes))),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final freed = await ref
          .read(mediaRepositoryProvider)
          .clearCachedMedia(ids);
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.storageFreed(formatBytes(freed)))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final stats = _stats;

    return SettingsScaffold(
      title: L.of(context).storageTitle,
      onRefresh: _refresh,
      children: [
        _StorageGauge(pokouBytes: stats?.totalBytes, disk: _disk),
        // REG-2 · Gérer le stockage : ce que prend chaque discussion.
        SettingsSectionTitle(L.of(context).storageManage),
        SettingsCard(
          children: [
            for (final entry in _topDiscussions())
              _DiscussionRow(
                name: _discussionName(context, entry.key),
                size: formatBytes(entry.value),
                onTap: _busy
                    ? null
                    : () => _free(
                        _discussionName(context, entry.key),
                        _idsByDiscussion[entry.key] ?? const {},
                        entry.value,
                      ),
              ),
            SettingsRow(
              label: L.of(context).storageBigFiles,
              trailing: SettingsValue('$_bigFiles'),
              onTap: _busy || _bigIds.isEmpty
                  ? null
                  : () => _free(
                      L.of(context).storageBigFiles,
                      _bigIds,
                      _bigBytes,
                    ),
            ),
          ],
        ),
        // REG-2 · Téléchargement automatique, selon le réseau.
        SettingsSectionTitle(L.of(context).storageAutoDownload),
        SettingsCard(
          children: [
            SettingsRow(
              label: L.of(context).storageMobileData,
              trailing: SettingsValue(
                _autoLabel(context, settings.autoDownloadMobile),
              ),
              onTap: () => _chooseAuto(
                wifi: false,
                current: settings.autoDownloadMobile,
              ),
            ),
            SettingsRow(
              label: L.of(context).storageOnWifi,
              trailing: SettingsValue(
                _autoLabel(context, settings.autoDownloadWifi),
              ),
              onTap: () =>
                  _chooseAuto(wifi: true, current: settings.autoDownloadWifi),
            ),
            SettingsRow(
              label: L.of(context).storageCallSaver,
              subtitle: L.of(context).storageCallSaverSub,
              trailing: SettingsSwitch(
                value: settings.callDataSaver,
                semanticLabel: L.of(context).storageCallSaver,
                onChanged: ref
                    .read(appSettingsProvider.notifier)
                    .setCallDataSaver,
              ),
            ),
            // Absente de la maquette, gardée : c'est elle qui coupe tout
            // téléchargement automatique, et l'ôter laisserait coincé qui
            // l'a déjà activée.
            SettingsRow(
              label: L.of(context).storageDataSaver,
              subtitle: L.of(context).storageDataSaverSub,
              trailing: SettingsSwitch(
                value: settings.dataSaver,
                semanticLabel: L.of(context).storageDataSaver,
                onChanged: ref.read(appSettingsProvider.notifier).setDataSaver,
              ),
            ),
          ],
        ),
        SettingsFootnote(L.of(context).storageDataSaverFootnote),
      ],
    );
  }
}

extension on _StorageSettingsScreenState {
  List<MapEntry<String, int>> _topDiscussions() {
    final entries = _byDiscussion.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  String _discussionName(BuildContext context, String key) {
    if (key == 'other') return L.of(context).storageOtherDiscussion;
    final parts = key.split(':');
    final id = int.tryParse(parts.last);
    final list = ref.read(discussionsProvider).valueOrNull ?? const [];
    for (final d in list) {
      if (parts.first == 'group' && d.kind == 'group' && d.id == id)
        return d.name;
      if (parts.first == 'contact' && d.contactUserId == id) return d.name;
    }
    return L.of(context).storageOtherDiscussion;
  }

  String _autoLabel(BuildContext context, AutoDownload value) {
    final l = L.of(context);
    return switch (value) {
      AutoDownload.none => l.autoDownloadNone,
      AutoDownload.photos => l.autoDownloadPhotos,
      AutoDownload.photosVideos => l.autoDownloadPhotosVideos,
      AutoDownload.all => l.autoDownloadAll,
    };
  }

  Future<void> _chooseAuto({
    required bool wifi,
    required AutoDownload current,
  }) async {
    final picked = await showModalBottomSheet<AutoDownload>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<AutoDownload>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(sheetContext, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in AutoDownload.values)
                RadioListTile<AutoDownload>(
                  value: value,
                  title: Text(_autoLabel(context, value)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    await ref
        .read(appSettingsProvider.notifier)
        .setAutoDownload(wifi: wifi, value: picked);
  }
}

/// « Téléphone · 32 Go — 3,1 Go libres », et la barre Pokou · Autres ·
/// Libre. Sans la place du téléphone (iOS, web), Pokou seul.
class _StorageGauge extends StatelessWidget {
  const _StorageGauge({required this.pokouBytes, required this.disk});

  final int? pokouBytes;
  final ({int total, int free})? disk;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pokou = pokouBytes ?? 0;
    final disk = this.disk;
    final total = disk?.total ?? 0;
    final free = disk?.free ?? 0;
    final others = disk == null ? 0 : (total - free - pokou).clamp(0, total);
    // Une part minuscule reste visible : 1,8 Go sur 32 se voit à peine.
    int flex(int bytes) =>
        total == 0 || bytes == 0 ? 0 : (bytes * 1000 ~/ total).clamp(8, 1000);

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    disk == null
                        ? l.storagePokouOnly(
                            pokouBytes == null ? '…' : formatBytes(pokou),
                          )
                        : l.storagePhone(formatBytes(total)),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (disk != null)
                  Text(
                    l.storageFreeSpace(formatBytes(free)),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            if (disk != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (flex(pokou) > 0)
                        Expanded(
                          flex: flex(pokou),
                          child: ColoredBox(color: AppColors.accentPrimary),
                        ),
                      if (flex(others) > 0)
                        Expanded(
                          flex: flex(others),
                          child: ColoredBox(color: AppColors.border),
                        ),
                      if (flex(free) > 0)
                        Expanded(
                          flex: flex(free),
                          child: ColoredBox(color: AppColors.feedbackSuccess),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  legend(
                    AppColors.accentPrimary,
                    'Pokou ${formatBytes(pokou)}',
                  ),
                  legend(AppColors.border, l.storageOthers),
                  legend(AppColors.feedbackSuccess, l.storageFreeLabel),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une discussion : ses initiales, son nom, sa place, et le geste pour la
/// libérer.
class _DiscussionRow extends StatelessWidget {
  const _DiscussionRow({
    required this.name,
    required this.size,
    required this.onTap,
  });

  final String name;
  final String size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ContactAvatar(avatar: null, displayName: name, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            SettingsValue(size),
          ],
        ),
      ),
    );
  }
}
