import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final stats = await ref.read(mediaRepositoryProvider).cacheStats();
      if (mounted) setState(() => _stats = stats);
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
        SettingsSectionTitle(L.of(context).storageMobileData),
        SettingsCard(
          children: [
            SettingsRow(
              icon: Icons.signal_cellular_alt,
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
