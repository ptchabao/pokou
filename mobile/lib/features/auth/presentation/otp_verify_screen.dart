import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/assistant_orb.dart';
import '../../../core/widgets/pokou_back_button.dart';
import '../../../core/widgets/pokou_background.dart';
import '../data/auth_repository.dart' show TwoStepRequired;
import 'auth_controller.dart';
import 'onboarding_screen.dart';
import 'two_step_pin_screen.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../../core/settings/app_settings.dart';

const _codeLength = 6;

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen>
    with TickerProviderStateMixin {
  /// Les textes traduits, lus à travers le `context` de cet État.
  ///
  /// Un raccourci et non une variable capturée : après un `await`, la
  /// variable pointerait sur la langue d'AVANT si l'utilisateur vient d'en
  /// changer, alors que le getter relit toujours la bonne.
  L get _l => L.of(context);

  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shakeController;
  late final AnimationController _successController;
  bool _success = false;
  String? _error;

  /// 50 s, comme le serveur (RESEND_MIN_SECONDS, égal à la durée de vie du
  /// code) : un bouton qui se réactive avant que le serveur accepte ne
  /// produirait qu'un refus, et après, le code aurait déjà expiré.
  static const _cooldownSeconds = 50;
  int _resendCooldown = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    _codeController.addListener(() => setState(() {}));
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _startCooldown() {
    _resendCooldown = _cooldownSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != _codeLength) return;
    setState(() => _error = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(
            phone: widget.phone,
            code: _codeController.text.trim(),
            // On n'arrive ici qu'en ayant touché « Accepter et continuer »
            // sur INS-1 : l'acceptation des conditions et de l'âge est donc
            // acquise, et s'enregistre une fois le numéro prouvé (AUTH-09).
            acceptTerms: true,
            ageConfirmed: true,
          );
      // Le numéro vient d'être confirmé par SMS : son pays est le seul que
      // l'application connaisse avec certitude. On le retient pour le
      // proposer par défaut à la prochaine connexion sur cet appareil,
      // plutôt que de redemander à la locale — qui se trompe.
      _rememberCountry(widget.phone);
      if (!mounted) return;
      // Pas de secousse à cacher, pas de "..." — juste la coche qui se
      // dessine, puis le fondu vers le noir du chat prend le relais.
      setState(() => _success = true);
      await _successController.forward();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final next = await routeAfterSignIn(ref);
      if (mounted) context.go(next);
    } on TwoStepRequired catch (pending) {
      // Le SMS est validé, le compte demande encore son code : le numéro
      // est donc confirmé, on peut retenir son pays dès maintenant.
      _rememberCountry(widget.phone);
      if (!mounted) return;
      _codeController.clear();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              TwoStepPinScreen(verificationToken: pending.verificationToken),
        ),
      );
    } on ApiException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail(_l.errorNetwork);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _error = message;
      _codeController.clear();
    });
    _shakeController.forward(from: 0);
  }

  Future<void> _resendSms() => _resend('sms', _l.authCodeSentSms);

  /// Renvoi par WhatsApp SEUL.
  ///
  /// C'est le recours de quelqu'un dont le code a expiré sans jamais
  /// arriver : la livraison SMS est régulièrement lente ou perdue par
  /// l'opérateur, et repartir par le même chemin coûte un message pour
  /// refaire exactement ce qui vient d'échouer.
  Future<void> _resendWhatsApp() =>
      _resend('whatsapp', _l.authCodeSentWhatsapp);

  Future<void> _resend(String channel, String confirmation) async {
    setState(() => _error = null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.phone, channel: channel);
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(confirmation)));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  String _formatCooldown(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _rememberCountry(String phone) {
    try {
      final iso = PhoneNumber.parse(phone).isoCode.name;
      unawaited(
        ref.read(appSettingsProvider.notifier).rememberPhoneCountry(iso),
      );
    } catch (_) {
      // Un numéro que le parseur refuse ne doit pas faire échouer une
      // connexion déjà réussie : on renonce simplement à mémoriser.
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Le retour n'existe que tant qu'on peut encore corriger le
                // numéro. Une fois le code validé, la connexion est faite :
                // une flèche de retour y proposerait de revenir sur quelque
                // chose qui n'est plus modifiable.
                if (!_success) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: PokouBackButton(),
                  ),
                  const SizedBox(height: 16),
                ],
                const Center(child: AssistantOrb(size: 80)),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _success ? _buildSuccess() : _buildForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      key: const ValueKey('success'),
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _successController,
          curve: Curves.easeOutBack,
        ),
        child: const Icon(
          Icons.check_circle,
          color: AppColors.focusRing,
          size: 72,
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          L.of(context).onbStep('2'),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          L.of(context).authVerifyTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          L.of(context).authCodeSentTo(widget.phone),
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              L.of(context).authChangeNumber,
              style: TextStyle(
                color: AppColors.accentPrimaryDark,
                decoration: TextDecoration.underline,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            // Secousse : quelques allers-retours amortis plutôt qu'un
            // simple sin() — se sent plus "physique".
            final offset = t == 0
                ? 0.0
                : (1 - t) * 10 * (t * 40).remainder(2) - 5;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
          child: _buildOtpBoxes(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.chatIconMuted,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(child: _buildResendArea()),
      ],
    );
  }

  Widget _buildOtpBoxes() {
    final code = _codeController.text;
    final hasFocus = _focusNode.hasFocus;
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                _OtpBox(
                  digit: i < code.length ? code[i] : null,
                  active: hasFocus && i == code.length,
                ),
              ],
            ],
          ),
          // Champ réel invisible qui capte la saisie/le collage (long
          // appui) — les 6 cases ne sont qu'un rendu de son contenu.
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: _codeLength * 64,
              child: TextField(
                controller: _codeController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: _codeLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  if (value.length == _codeLength) _verify();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendArea() {
    if (_resendCooldown > 0) {
      return Text(
        L.of(context).authResendIn(_formatCooldown(_resendCooldown)),
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }
    return Column(
      children: [
        Text(
          L.of(context).otpNoCodeReceived,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            TextButton(
              onPressed: _resendSms,
              child: Text(
                L.of(context).authResendSms,
                style: TextStyle(
                  color: AppColors.accentPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: _resendWhatsApp,
              child: Text(
                L.of(context).authResendWhatsapp,
                style: TextStyle(
                  color: AppColors.accentPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: 44,
      height: 48,
      alignment: Alignment.center,
      transform: digit != null
          ? Matrix4.translationValues(0.0, -2.0, 0.0)
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: active ? AppColors.focusRing : AppColors.border,
            width: 2,
          ),
        ),
      ),
      child: Text(
        digit ?? '',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
