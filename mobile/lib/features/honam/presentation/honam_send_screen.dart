import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../modules/shared/module_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_order_screen.dart';
import 'honam_screen.dart';
import '../../../core/widgets/pokou_context_menu.dart';

/// La position, demandée au moment où elle sert : trier les officines et
/// guider le coursier. Refusée, l'annuaire reste dans l'ordre alphabétique.
///
/// [ask] à `false` : on ne lit la position que si elle est DÉJÀ autorisée.
/// Ouvrir l'onglet Honam ne doit pas faire surgir la demande du système
/// avant que la personne ait fait quoi que ce soit ; elle arrive au moment
/// d'envoyer une ordonnance, quand sa raison est évidente.
Future<Position?> currentPosition({bool ask = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Envoyer une ordonnance : photo, officine, adresse. Trois choses, sur un
/// seul écran.
class HonamSendScreen extends ConsumerStatefulWidget {
  const HonamSendScreen({super.key, this.resendFromOrderId});

  /// Renvoi après un refus : la photo est reprise de la commande d'origine.
  final int? resendFromOrderId;

  @override
  ConsumerState<HonamSendScreen> createState() => _HonamSendScreenState();
}

class _HonamSendScreenState extends ConsumerState<HonamSendScreen> {
  final _address = TextEditingController();
  final _note = TextEditingController();
  XFile? _photo;
  Position? _position;
  List<Pharmacy> _pharmacies = const [];
  int? _pharmacyId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isResend => widget.resendFromOrderId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _position = await currentPosition();
    try {
      final items = await ref
          .read(honamRepositoryProvider)
          .pharmacies(lat: _position?.latitude, lng: _position?.longitude);
      if (!mounted) return;
      setState(() {
        _pharmacies = items;
        // La plus proche par défaut : c'est la règle de HONAM (BM-12).
        _pharmacyId = items.isEmpty ? null : items.first.id;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 2000,
    );
    if (photo != null) setState(() => _photo = photo);
  }

  Future<void> _submit() async {
    final l = L.of(context);
    if (_pharmacyId == null) return;
    if (!_isResend && _photo == null) {
      setState(() => _error = l.honamNeedPhoto);
      return;
    }
    if (!_isResend && _address.text.trim().length < 3) {
      setState(() => _error = l.honamNeedAddress);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(honamRepositoryProvider);
      final HonamOrder order;
      if (_isResend) {
        order = await repository.action(
          widget.resendFromOrderId!,
          'resend',
          body: {'pharmacy_id': _pharmacyId},
        );
      } else {
        final upload = await ref
            .read(mediaRepositoryProvider)
            .upload(
              bytes: await File(_photo!.path).readAsBytes(),
              filename: 'ordonnance.jpg',
              mimeType: 'image/jpeg',
              messageType: 'IMAGE',
              memoriser: false,
            );
        order = await repository.submit(
          pharmacyId: _pharmacyId!,
          prescriptionMediaId: upload.id,
          address: _address.text.trim(),
          lat: _position?.latitude,
          lng: _position?.longitude,
          note: _note.text.trim(),
        );
      }
      ref.invalidate(honamOrdersProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: order.id)),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.honamFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ModuleScaffold(
      title: _isResend ? l.honamResend : l.honamSend,
      subtitle: l.honamSubtitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (!_isResend) ...[
            if (_photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_photo!.path),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ModuleActionButton(
                    label: l.honamPhotograph,
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ModuleQuietButton(
                    label: l.honamFromGallery,
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _address,
              maxLength: 255,
              decoration: InputDecoration(labelText: l.honamAddress),
            ),
            TextField(
  contextMenuBuilder: pokouContextMenuBuilder,
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(labelText: l.honamNote),
            ),
          ],
          ModuleSectionTitle(l.honamChoosePharmacy),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_pharmacies.isEmpty)
            Text(
              l.honamNoPharmacy,
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final p in _pharmacies)
              PharmacyTile(
                pharmacy: p,
                selected: p.id == _pharmacyId,
                onTap: () => setState(() => _pharmacyId = p.id),
              ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: AppColors.feedbackDanger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.feedbackDanger),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l.honamNotEmergency,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ModuleActionButton(
            label: l.honamSubmit,
            busy: _busy,
            onPressed: _busy || _pharmacyId == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
