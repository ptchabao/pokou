import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Filet fin gris 6% — pas de Divider() plein qui traverse l'écran bord à
/// bord ; un vrai séparateur de liste « groupée » reste en retrait des bords.
const settingsHairline = Color(0x0F000000);

/// Échafaudage commun aux écrans de réglages poussés depuis l'onglet Profil :
/// même fond, même barre de titre, mêmes marges. Les listes « groupées »
/// (SettingsCard) et les lignes (SettingsRow) reprennent exactement la
/// présentation de la page Profil, pour qu'un écran poussé ne ressemble pas à
/// une autre app.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      children: children,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list),
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Texte explicatif sous une section — sert à dire ce qu'un réglage fait
/// VRAIMENT (et ce qu'il ne fait pas), plutôt que de laisser l'utilisateur le
/// deviner d'après son libellé.
class SettingsFootnote extends StatelessWidget {
  const SettingsFootnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: settingsHairline,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.semanticError : AppColors.textPrimary;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: destructive ? color : AppColors.textSecondary,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: color, fontSize: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
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

/// Interrupteur de réglage — même apparence que celui du Mode Bouclier sur la
/// page Profil (piste noire de marque, pouce blanc).
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Switch(
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.accentPrimary,
        onChanged: onChanged,
      ),
    );
  }
}
