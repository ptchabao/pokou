import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../../core/widgets/pokou_background.dart';
import 'auth_controller.dart';
import 'phone_country.dart';
import '../../../core/settings/app_settings.dart';
import '../data/sim_country.dart';

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  /// Les textes traduits, lus à travers le `context` de cet État.
  ///
  /// Un raccourci et non une variable capturée : après un `await`, la
  /// variable pointerait sur la langue d'AVANT si l'utilisateur vient d'en
  /// changer, alors que le getter relit toujours la bonne.
  L get _l => L.of(context);

  // Le champ ne contient QUE le numéro national : l'indicatif vit dans le
  // sélecteur à sa gauche. Avant, le champ était prérempli « +228 » et rien
  // n'indiquait qu'on pouvait l'effacer — l'écran s'adressait de fait aux
  // seuls Togolais, et un Ivoirien qui tapait son numéro local finissait
  // enregistré comme numéro togolais.
  final _phoneController = TextEditingController();
  final _focusNode = FocusNode();

  /// Renseigné dans initState : `ref` n'est pas lisible dans un
  /// initialiseur de champ.
  late PhoneCountry _country;
  bool _loading = false;

  /// Vrai dès que l'utilisateur a choisi un pays lui-même. La détection
  /// tardive par la SIM ne doit plus rien changer après ça.
  bool _countryTouched = false;
  bool _focused = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Une première réponse tout de suite, sans attendre le matériel : le
    // champ doit être utilisable à la première image. La carte SIM, elle,
    // se lit de façon asynchrone et corrigera ce choix juste après.
    _country = detectPhoneCountry(
      rememberedIso: ref.read(appSettingsProvider).phoneCountryIso,
    );
    _refineFromSim();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Un numéro collé au format international (« +225 07 12 34 56 78 »)
  /// remplit le champ ET repositionne le sélecteur, au lieu d'être recollé
  /// derrière l'indicatif déjà choisi.
  void _onPhoneChanged() {
    final raw = _phoneController.text;
    if (raw.startsWith('+') && raw.length > 4) {
      try {
        final parsed = PhoneNumber.parse(raw);
        final country = phoneCountryFor(parsed.isoCode);
        if (country != null) {
          _country = country;
          _phoneController.value = TextEditingValue(
            text: parsed.nsn,
            selection: TextSelection.collapsed(offset: parsed.nsn.length),
          );
        }
      } catch (_) {
        // Pas (encore) un numéro international reconnaissable — on laisse
        // taper : la validation se fera à l'envoi.
      }
    }
    setState(() {});
  }

  /// Le numéro tel qu'il partira au serveur : E.164, indicatif compris.
  /// Toujours explicite, jamais déduit d'un pays par défaut côté API.
  String get _e164 =>
      '+${_country.dialCode}${_phoneController.text.replaceAll(RegExp(r'[^0-9]'), '')}';

  /// Validé par la base libphonenumber du paquet, pas par un compte de
  /// chiffres : « au moins 8 chiffres » acceptait des numéros impossibles et
  /// refusait des pays aux numéros plus courts.
  bool get _isValidNumber {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return false;
    try {
      return PhoneNumber.parse(_e164).isValid();
    } catch (_) {
      return false;
    }
  }

  /// Affine le pays proposé avec celui de la carte SIM.
  ///
  /// Après coup, et sans bloquer : lire la SIM prend quelques
  /// millisecondes, et faire attendre l'écran de connexion pour un
  /// préremplissage serait un mauvais échange.
  ///
  /// Ne touche à rien si l'utilisateur a déjà choisi ou commencé à taper :
  /// corriger un pays sous les doigts de quelqu'un est pire que de se
  /// tromper.
  Future<void> _refineFromSim() async {
    final simIso = await const SimCountry().isoCode();
    if (simIso == null || !mounted) return;
    if (_countryTouched || _phoneController.text.isNotEmpty) return;
    final refined = detectPhoneCountry(
      rememberedIso: ref.read(appSettingsProvider).phoneCountryIso,
      simIso: simIso,
    );
    if (refined.isoCode != _country.isoCode) {
      setState(() => _country = refined);
    }
  }

  Future<void> _pickCountry() async {
    final chosen = await showPhoneCountryPicker(context, current: _country);
    if (chosen == null || !mounted) return;
    setState(() {
      _country = chosen;
      _countryTouched = true;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final phone = _e164;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/otp', extra: phone);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = _l.errorNetwork);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _isValidNumber && !_loading;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PokouBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Center(child: AssistantOrb(size: 80)),
                const SizedBox(height: 28),
                Text(
                  L.of(context).authWelcome,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  L.of(context).authSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: _focused ? AppColors.focusRing : AppColors.border,
                      width: _focused ? 2 : 1,
                    ),
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: AppColors.focusRing.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : AppElevation.subtle,
                  ),
                  child: Row(
                    children: [
                      // Drapeau + indicatif : c'est le bouton du sélecteur,
                      // et non une décoration comme le drapeau togolais
                      // fixe d'avant.
                      InkWell(
                        onTap: _loading ? null : _pickCountry,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 18, 6, 18),
                          child: Row(
                            children: [
                              Text(
                                _country.flag,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '+${_country.dialCode}',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 26, color: AppColors.border),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+ ]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            // Un exemple de numéro DU PAYS CHOISI : « 90 12
                            // 34 56 » au Togo, « 06 12 34 56 78 » en France.
                            hintText: _country.exampleNsn.isEmpty
                                ? L.of(context).authPhoneHint
                                : _country.exampleNsn,
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 18,
                            ),
                          ),
                          onSubmitted: (_) => canSubmit ? _submit() : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.semanticError),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit
                        ? AppColors.accentPrimaryDark
                        : AppColors.border,
                    foregroundColor: canSubmit
                        ? Colors.white
                        : AppColors.textMuted,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.textMuted,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(L.of(context).actionContinue),
                ),
                const SizedBox(height: 24),
                // Formulation honnête : Pokou ne fait PAS de chiffrement de
                // bout en bout aujourd'hui — inutile de le promettre ici.
                Text(
                  L.of(context).authPrivacyNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
