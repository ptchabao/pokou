import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/country/country_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_elevation.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_bottom_nav.dart' show isLot1;
import '../../../core/widgets/pokou_background.dart';
import '../../profile/presentation/language_screen.dart';
import 'auth_controller.dart';
import 'legal_screen.dart';
import 'phone_country.dart';
import '../../../core/settings/app_settings.dart';
import '../data/sim_country.dart';
import '../../../core/widgets/pokou_context_menu.dart';

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
    // INS-1 (cahier v3.2) : bienvenue, numéro et conditions en UN écran, et
    // une seule entrée pour créer un compte ou se reconnecter (AUTH-08) —
    // c'est le serveur qui distingue les deux, après le code. Le bouton
    // « Accepter et continuer » vaut acceptation des conditions et de l'âge
    // (AUTH-09) : il n'y a donc plus de cases à cocher ici ni plus loin.
    final canSubmit = _isValidNumber && !_loading;
    // Avant toute connexion, le pays n'est connu que par l'indicatif choisi
    // dans le sélecteur — la même supposition que le repli hors-ligne
    // (`CountryConfig.guessFromPhone`), pour ne jamais promettre Kory ou
    // Honam là où le serveur ne les ouvrirait pas.
    final lot1 = isLot1(
      CountryConfig.guessFromPhone('+${_country.dialCode}').modules,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PokouBackground(
        child: SafeArea(
          // Défilant : la colonne dépasse la hauteur d'un petit téléphone
          // dès que le texte est agrandi.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // INS-1 : bienvenue, numéro et conditions réunis. Le
                    // sélecteur de langue reste accessible avant toute
                    // connexion — c'est la première chose dont a besoin
                    // quelqu'un qui ne lit pas le français.
                    Align(
                      alignment: Alignment.centerRight,
                      child: _LanguagePill(),
                    ),
                    Center(
                      child: Image.asset(
                        'assets/brand/pokou_logotype_couleur.png',
                        height: 48,
                        fit: BoxFit.contain,
                        semanticLabel: L.of(context).appName,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      L.of(context).welcomePromise,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Maquette INS-1 : une carte à 3 lignes, pas 5 — ce que
                    // le pays choisi ouvre vraiment (Kory/Honam) ou, en
                    // Lot 1, ce que la messagerie offre déjà (statuts,
                    // preuve des échanges).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _Service(
                            icon: Icons.forum_outlined,
                            label: L.of(context).welcomeServiceChats,
                          ),
                          if (lot1) ...[
                            _Service(
                              icon: Icons.donut_large_outlined,
                              label: L.of(context).welcomeServiceStatus,
                            ),
                            _Service(
                              icon: Icons.verified_outlined,
                              label: L.of(context).welcomeServiceProof,
                            ),
                          ] else ...[
                            _Service(
                              icon: Icons.savings_outlined,
                              label: L.of(context).welcomeServiceKory,
                            ),
                            _Service(
                              icon: Icons.local_pharmacy_outlined,
                              label: L.of(context).honamSubtitle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      L.of(context).authPhoneHint,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: _focused
                              ? AppColors.focusRing
                              : AppColors.border,
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
                          Container(
                            width: 1,
                            height: 26,
                            color: AppColors.border,
                          ),
                          Expanded(
                            child: TextField(
                              contextMenuBuilder: pokouContextMenuBuilder,
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
                                    ? L.of(context).authPhoneGenericHint
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
                    const SizedBox(height: 8),
                    Text(
                      L.of(context).authSubtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Maquette INS-1 : qui a déjà ce numéro dans ses contacts
                    // le retrouvera — annoncé avant l'inscription, pas après.
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              L.of(context).authContactsNotice,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // AUTH-09 : l'acceptation des conditions et de l'âge est
                    // portée par le bouton lui-même, pas par des cases à
                    // cocher — annoncée ici, en une phrase, les deux
                    // documents restant lisibles par leurs liens.
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: L.of(context).authAcceptIntro),
                          TextSpan(
                            text: L.of(context).legalTerms,
                            style: TextStyle(
                              color: AppColors.accentPrimaryDark,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const LegalScreen(name: 'conditions'),
                                ),
                              ),
                          ),
                          TextSpan(text: L.of(context).authAcceptAnd),
                          TextSpan(
                            text: L.of(context).legalPrivacy,
                            style: TextStyle(
                              color: AppColors.accentPrimaryDark,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LegalScreen(
                                    name: 'confidentialite',
                                  ),
                                ),
                              ),
                          ),
                          TextSpan(text: L.of(context).authAcceptEnd),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
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
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(L.of(context).authAcceptAndContinue),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une ligne de la carte des services ouverts dans le pays (maquette INS-1).
class _Service extends StatelessWidget {
  const _Service({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accentPrimaryDark),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// La puce de langue (maquette INS-1) : le globe, la langue courante, et un
/// chevron — pas juste une icône, pour que la langue déjà choisie se voie
/// sans ouvrir l'écran.
class _LanguagePill extends ConsumerWidget {
  const _LanguagePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(
      appSettingsProvider.select((settings) => settings.localeCode),
    );
    // Sans choix explicite, l'app suit le téléphone (voir AppSettings) : on
    // affiche alors la langue réellement rendue, celle de ce `context`.
    final label = LanguageScreen.nativeNameOf(
      code ?? Localizations.localeOf(context).languageCode,
    );
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const LanguageScreen())),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              Icon(Icons.expand_more, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
