import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../honam/presentation/honam_ui.dart';
import '../data/officine_models.dart';
import 'officine_controller.dart';
import 'officine_ui.dart';

/// Les motifs de refus (maquette R1).
enum OfficineRejectReason {
  unavailable,
  illegible,
  inPerson,
  expired,
  outOfZone,
  other,
}

/// Officine · R1. Refuser l'ordonnance.
///
/// Un motif, et le message que lira la patiente — prérempli selon le motif,
/// modifiable. C'est ce message que le serveur garde comme motif du refus.
/// Une photo illisible ne mérite pas toujours un refus : « Plutôt demander
/// une nouvelle photo » écrit à la patiente sans refuser.
class OfficineRejectScreen extends ConsumerStatefulWidget {
  const OfficineRejectScreen({super.key, required this.order});

  final OfficineOrder order;

  @override
  ConsumerState<OfficineRejectScreen> createState() =>
      _OfficineRejectScreenState();
}

class _OfficineRejectScreenState extends ConsumerState<OfficineRejectScreen> {
  OfficineRejectReason _reason = OfficineRejectReason.unavailable;
  final _message = TextEditingController();
  bool _edited = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_edited) _message.text = _template(_reason);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String get _patient => officinePatient(context, widget.order);

  String _template(OfficineRejectReason reason) {
    final l = L.of(context);
    return switch (reason) {
      OfficineRejectReason.unavailable => l.offiRejectMsgUnavailable(_patient),
      OfficineRejectReason.illegible => l.offiRejectMsgIllegible(_patient),
      OfficineRejectReason.inPerson => l.offiRejectMsgInPerson(_patient),
      OfficineRejectReason.expired => l.offiRejectMsgExpired(_patient),
      OfficineRejectReason.outOfZone => l.offiRejectMsgOutOfZone(_patient),
      OfficineRejectReason.other => l.offiRejectMsgOther(_patient),
    };
  }

  void _choose(OfficineRejectReason reason) => setState(() {
    _reason = reason;
    if (!_edited) _message.text = _template(reason);
  });

  Future<void> _reject() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _message.text.trim();
    if (text.length < 3) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(officineRepositoryProvider)
          .act(widget.order.id, 'reject', body: {'reason': text});
      HapticFeedback.lightImpact();
      refreshOfficine(ref, widget.order.id);
      // L'écran de la commande, dessous, passe de lui-même à R2.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Écrire à la patiente sans refuser : la commande reste ouverte.
  Future<void> _askNewPhoto() async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(officineRepositoryProvider)
          .sendMessage(widget.order.id, l.offiAskPhotoMessage(_patient));
      messenger.showSnackBar(
        SnackBar(content: Text(l.offiMessageSentTo(_patient))),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(officineError(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final reasons = [
      (
        OfficineRejectReason.unavailable,
        l.offiReasonUnavailable,
        l.offiReasonUnavailableHint(_patient),
      ),
      (
        OfficineRejectReason.illegible,
        l.offiReasonIllegible,
        l.offiReasonIllegibleHint,
      ),
      (
        OfficineRejectReason.inPerson,
        l.offiReasonInPerson,
        l.offiReasonInPersonHint(_patient),
      ),
      (
        OfficineRejectReason.expired,
        l.offiReasonExpired,
        l.offiReasonExpiredHint,
      ),
      (
        OfficineRejectReason.outOfZone,
        l.offiReasonOutOfZone,
        l.offiReasonOutOfZoneHint(_patient),
      ),
      (OfficineRejectReason.other, l.offiReasonOther, l.offiReasonOtherHint),
    ];
    return OfficinePage(
      title: l.offiRejectTitle,
      subtitle: l.offiPatientReceivedAt(
        _patient,
        officineTime(context, widget.order.createdAt),
      ),
      primary: HonamPrimaryButton(
        label: l.offiRejectAndNotify(_patient),
        busy: _busy,
        onPressed: _reject,
      ),
      secondary: OfficineTextAction(
        label: l.actionCancel,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        OfficineCardTitle(l.offiReason),
        for (final (value, title, hint) in reasons)
          OfficineChoice<OfficineRejectReason>(
            value: value,
            group: _reason,
            onChanged: _choose,
            title: title,
            subtitle: hint,
          ),
        const SizedBox(height: 8),
        OfficineCardTitle(l.offiMessageFor(_patient)),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: 255,
          onChanged: (_) => _edited = true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OfficineTextAction(
            label: l.offiAskNewPhoto,
            icon: Icons.photo_camera_outlined,
            onPressed: _busy ? null : _askNewPhoto,
          ),
        ),
      ],
    );
  }
}
