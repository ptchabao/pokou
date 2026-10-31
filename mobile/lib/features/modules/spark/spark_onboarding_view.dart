import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/paid_feature_widgets.dart';
import '../shared/module_ui.dart';
import 'spark_controller.dart';

/// La création de la fiche Spark.
///
/// Un écran à part entière, et non une feuille : c'est ici qu'on demande une
/// date de naissance qui ne pourra plus être corrigée, et une photo qui sera
/// montrée à des inconnus à moins de cinq kilomètres. Ça mérite mieux qu'un
/// formulaire glissé par le bas.
class SparkOnboardingView extends ConsumerStatefulWidget {
  const SparkOnboardingView({super.key});

  @override
  ConsumerState<SparkOnboardingView> createState() =>
      _SparkOnboardingViewState();
}

class _SparkOnboardingViewState extends ConsumerState<SparkOnboardingView> {
  final _nameController = TextEditingController();

  /// Les textes traduits, relus à chaque accès.
  L get _l => L.of(context);
  final _bioController = TextEditingController();
  DateTime? _birthDate;
  String _gender = 'F';
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final eighteen = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      // La fenêtre s'arrête à dix-huit ans : on ne propose pas une date qui
      // sera refusée juste après. Un formulaire qui laisse saisir une valeur
      // interdite ne fait que reporter le refus.
      initialDate: eighteen,
      firstDate: DateTime(now.year - 90),
      lastDate: eighteen,
      helpText: _l.sparkBirthDateLabel,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.length < 2 || _birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l.sparkNameAndBirthNeeded)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(sparkRepositoryProvider)
          .saveProfile(
            displayName: name,
            birthDate:
                '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
            gender: _gender,
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
          );
      ref.invalidate(sparkProfileProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l.sparkProfileFailed)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final birth = _birthDate;
    return ModuleScaffold(
      title: 'Spark',
      subtitle: _l.sparkCreateProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          ExplainerCard(
            steps: [
              (
                icon: Icons.today_outlined,
                title: _l.sparkStep1Title,
                body: _l.sparkStep1Body,
              ),
              (
                icon: Icons.mic_none,
                title: _l.sparkStep2Title,
                body: _l.sparkStep2Body,
              ),
              (
                icon: Icons.shield_outlined,
                title: _l.sparkStep3Title,
                body: _l.sparkStep3Body,
              ),
            ],
          ),
          FieldLabel(_l.sparkSeparateTitle),
          Text(
            _l.sparkSeparateBody,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          FieldLabel(_l.sparkDisplayName),
          TextField(
            controller: _nameController,
            maxLength: 60,
            decoration: InputDecoration(hintText: _l.sparkNameExample),
          ),
          FieldLabel(_l.sparkBirthDate),
          Text(
            _l.sparkBirthDateLocked,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ModuleCard(
            onTap: _pickBirthDate,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 12),
                Text(
                  birth == null
                      ? _l.sparkChoose
                      : '${birth.day.toString().padLeft(2, '0')}/${birth.month.toString().padLeft(2, '0')}/${birth.year}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: birth == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
          FieldLabel(_l.sparkYouAre),
          Wrap(
            spacing: 8,
            // Plus `const` : les libellés dépendent de la langue courante.
            children:
                [
                  ('F', _l.sparkWoman),
                  ('M', _l.sparkMan),
                  ('AUTRE', _l.sparkOther),
                ].map((option) {
                  final selected = _gender == option.$1;
                  return ChoiceChip(
                    label: Text(option.$2),
                    selected: selected,
                    showCheckmark: false,
                    backgroundColor: AppColors.surfaceElevated,
                    selectedColor: AppColors.accentPrimaryLight,
                    side: BorderSide(
                      color: selected
                          ? AppColors.accentPrimaryDark
                          : AppColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _gender = option.$1),
                  );
                }).toList(),
          ),
          FieldLabel(_l.sparkBioLabel),
          TextField(
            controller: _bioController,
            maxLength: 300,
            maxLines: 3,
            decoration: InputDecoration(hintText: _l.sparkBioHint),
          ),
          const SizedBox(height: 12),
          ModuleActionButton(
            label: _l.sparkCreateAction,
            busy: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          Text(
            _l.sparkAgeRestricted,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
