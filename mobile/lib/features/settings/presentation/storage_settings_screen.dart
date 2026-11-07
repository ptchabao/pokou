import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contacts/presentation/discussions_controller.dart';
import 'settings_widgets.dart';

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
      sizes.forEach((id, bytes) {
        final key = owners[id] ?? 'other';
        byDiscussion[key] = (byDiscussion[key] ?? 0) + bytes;
      });
      if (mounted) {
        setState(() {
          _stats = stats;
          _byDiscussion = byDiscussion;
          _bigFiles = sizes.values.where((b) => b > 5 * 1024 * 1024).length;
        });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _stats = const MediaCacheStats(fileCount: 0, totalBytes: 0),
        );
    }
  }

  Future<void> _clear() async {
    setState(() => _busy = true);
    try {
      final removed = await ref.read(mediaRepositoryProvider).clearCache();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed == 0
                ? L.of(context).storageNoCachedMedia
                : L.of(context).storageFilesCleared(removed),
          ),
        ),
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
        SettingsSectionTitle(L.of(context).storageCachedMedia),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.folder_outlined,
              label: L.of(context).storageMediaLabel,
              subtitle: stats == null
                  ? L.of(context).storageComputing
                  : stats.fileCount == 0
                  ? L.of(context).storageNoFile
                  : L
                        .of(context)
                        .storageFileCount(
                          stats.fileCount,
                          formatBytes(stats.totalBytes),
                        ),
              trailing: const SizedBox(),
            ),
            SettingsRow(
              icon: Icons.delete_outline,
              label: L.of(context).storageClearCache,
              destructive: true,
              onTap: _busy || (stats?.fileCount ?? 0) == 0 ? null : _clear,
              trailing: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textMuted,
                      ),
                    )
                  : null,
            ),
          ],
        ),
        SettingsFootnote(L.of(context).storageClearFootnote),
        // REG-2 · Gérer le stockage : ce que prend chaque discussion.
        SettingsSectionTitle(L.of(context).storageManage),
        SettingsCard(
          children: [
            for (final entry in _topDiscussions())
              SettingsRow(
                icon: entry.key.startsWith('group:')
                    ? Icons.groups_outlined
                    : Icons.person_outline,
                label: _discussionName(context, entry.key),
                trailing: Text(
                  formatBytes(entry.value),
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            SettingsRow(
              icon: Icons.insert_drive_file_outlined,
              label: L.of(context).storageBigFiles,
              trailing: Text(
                '$_bigFiles',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        // REG-2 · Téléchargement automatique, selon le réseau.
        SettingsSectionTitle(L.of(context).storageAutoDownload),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.signal_cellular_alt,
              label: L.of(context).storageMobileData,
              subtitle: _autoLabel(context, settings.autoDownloadMobile),
              onTap: () => _chooseAuto(
                wifi: false,
                current: settings.autoDownloadMobile,
              ),
            ),
            SettingsRow(
              icon: Icons.wifi,
              label: L.of(context).storageOnWifi,
              subtitle: _autoLabel(context, settings.autoDownloadWifi),
              onTap: () =>
                  _chooseAuto(wifi: true, current: settings.autoDownloadWifi),
            ),
            SettingsRow(
              icon: Icons.call_outlined,
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
            SettingsRow(
              icon: Icons.data_saver_on_outlined,
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
