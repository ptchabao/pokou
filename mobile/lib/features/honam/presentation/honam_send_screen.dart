import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/pokou_context_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../kory/presentation/kory_ui.dart';
import '../data/honam_models.dart';
import 'honam_controller.dart';
import 'honam_order_screen.dart';
import 'honam_ui.dart';
import '../../../core/widgets/pokou_sheet.dart';
import '../../../core/location/pokou_location.dart';

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

/// « Ouverte · Tokoin · 1,2 km », « De garde · Bè · 2,4 km » : ce que
/// l'annuaire sait d'une officine, les mêmes champs pour toutes (BM-12).
String honamPharmacyLine(BuildContext context, Pharmacy pharmacy) {
  final l = L.of(context);
  return [
    if (pharmacy.isOnDuty) l.honamOnDuty,
    if (pharmacy.openingHours != null && !pharmacy.isOnDuty)
      pharmacy.openingHours!,
    if (pharmacy.address.isNotEmpty) pharmacy.address,
    if (pharmacy.distanceKm != null)
      l.honamUiKm(
        NumberFormat.decimalPatternDigits(
          locale: Localizations.localeOf(context).toLanguageTag(),
          decimalDigits: 1,
        ).format(pharmacy.distanceKm!),
      ),
  ].join(' · ');
}

/// Envoyer une ordonnance (maquette Honam patient 1) : la photo, la
/// pharmacie, l'adresse et son repère, un mot pour la pharmacie. Le bouton
/// du bas nomme la pharmacie choisie.
class HonamSendScreen extends ConsumerStatefulWidget {
  const HonamSendScreen({super.key});

  @override
  ConsumerState<HonamSendScreen> createState() => _HonamSendScreenState();
}

class _HonamSendScreenState extends ConsumerState<HonamSendScreen> {
  final _note = TextEditingController();
  XFile? _photo;
  Position? _position;
  List<Pharmacy> _pharmacies = const [];
  int? _pharmacyId;
  String _address = '';
  String _landmark = '';
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // L'adresse de la dernière commande, pour ne pas la retaper.
    try {
      final orders = await ref.read(honamOrdersProvider.future);
      if (orders.isNotEmpty && mounted) {
        setState(() {
          _address = orders.first.deliveryAddress;
          _landmark = orders.first.deliveryLandmark ?? '';
        });
      }
    } catch (_) {}
    // Au moment d'envoyer une ordonnance, la raison est évidente : si la
    // localisation est coupée ou refusée, on propose de l'activer (au lieu
    // d'un annuaire silencieusement non trié).
    try {
      _position = mounted ? await obtainPosition(context) : null;
    } catch (_) {
      _position = null;
    }
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
    _note.dispose();
    super.dispose();
  }

  Pharmacy? get _pharmacy =>
      _pharmacies.where((p) => p.id == _pharmacyId).firstOrNull;

  Future<void> _pick(ImageSource source) async {
    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 2000,
    );
    if (photo != null) setState(() => _photo = photo);
  }

  Future<void> _choosePhoto() async {
    final l = L.of(context);
    final source = await showPokouSheet<ImageSource>(
      scrollable: true,
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.honamPhotograph),
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.honamFromGallery),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _editAddress() async {
    final result = await showPokouSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (_) => _AddressSheet(address: _address, landmark: _landmark),
    );
    if (result != null) {
      setState(() {
        _address = result.$1;
        _landmark = result.$2;
      });
    }
  }

  Future<void> _submit() async {
    final l = L.of(context);
    final pharmacy = _pharmacy;
    if (pharmacy == null) return;
    if (_photo == null) {
      koryToast(context, l.honamNeedPhoto);
      return;
    }
    if (_address.trim().length < 3) {
      koryToast(context, l.honamNeedAddress);
      await _editAddress();
      return;
    }
    setState(() => _busy = true);
    try {
      final upload = await ref
          .read(mediaRepositoryProvider)
          .upload(
            bytes: await File(_photo!.path).readAsBytes(),
            filename: 'ordonnance.jpg',
            mimeType: 'image/jpeg',
            messageType: 'IMAGE',
            memoriser: false,
          );
      final order = await ref
          .read(honamRepositoryProvider)
          .submit(
            pharmacyId: pharmacy.id,
            prescriptionMediaId: upload.id,
            address: _address.trim(),
            landmark: _landmark.trim(),
            lat: _position?.latitude,
            lng: _position?.longitude,
            note: _note.text.trim(),
          );
      ref.invalidate(honamOrdersProvider);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HonamOrderScreen(orderId: order.id)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      koryToast(context, l.honamFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final pharmacy = _pharmacy;
    return KoryPage(
      title: l.honamSend,
      footer: KoryFooter(
        children: [
          KoryButton(
            label: pharmacy == null
                ? l.honamSubmit
                : l.honamPSendTo(pharmacy.name),
            busy: _busy,
            onPressed: pharmacy == null ? null : _submit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PhotoCard(photo: _photo, onPick: _choosePhoto),
          KorySection(l.honamUiPharmacy),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_pharmacies.isEmpty)
            KoryNotice(text: l.honamNoPharmacy)
          else
            for (final p in _pharmacies.take(6))
              KoryChoice(
                selected: p.id == _pharmacyId,
                title: p.name,
                subtitle: honamPharmacyLine(context, p),
                onTap: () => setState(() => _pharmacyId = p.id),
              ),
          KoryCard(
            padding: EdgeInsets.zero,
            child: HonamLinkRow(
              icon: Icons.location_on_outlined,
              title: _address.isEmpty
                  ? l.honamPAddAddress
                  : l.honamPDeliverTo(_address),
              subtitle: _landmark.isEmpty ? null : l.honamPLandmark(_landmark),
              onTap: _editAddress,
            ),
          ),
          KorySection(l.honamPMessageToPharmacy),
          TextField(
            contextMenuBuilder: pokouContextMenuBuilder,
            controller: _note,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l.honamPMessageHint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          KoryNotice(tone: KoryTone.success, text: l.honamPPrivacyNotice),
        ],
      ),
    );
  }
}

/// La photo de l'ordonnance : la vignette, ce qu'il faut vérifier, et
/// « Reprendre ».
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onPick});

  final XFile? photo;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final picked = photo;
    if (picked == null) {
      return KoryCard(
        onTap: onPick,
        child: Row(
          children: [
            const HonamThumb(child: Icon(Icons.photo_camera_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.honamPhotograph,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    l.honamPPhotoHelp,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return KoryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(picked.path),
              width: 56,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HonamPill(
                  l.honamPPhotoAdded,
                  background: AppColors.feedbackSuccess.withValues(
                    alpha: AppColors.isDark ? 0.22 : 0.12,
                  ),
                  ink: AppColors.isDark
                      ? AppColors.textPrimary
                      : AppColors.feedbackSuccess,
                ),
                const SizedBox(height: 6),
                Text(
                  l.honamPPhotoHelp,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(l.honamPRetake),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// L'adresse de livraison et son repère.
class _AddressSheet extends StatefulWidget {
  const _AddressSheet({required this.address, required this.landmark});

  final String address;
  final String landmark;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  late final _address = TextEditingController(text: widget.address);
  late final _landmark = TextEditingController(text: widget.landmark);

  @override
  void dispose() {
    _address.dispose();
    _landmark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.honamAddress,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _address,
              autofocus: true,
              maxLength: 255,
              decoration: InputDecoration(labelText: l.honamAddress),
            ),
            TextField(
              contextMenuBuilder: pokouContextMenuBuilder,
              controller: _landmark,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: l.honamPLandmarkLabel,
                hintText: l.honamPLandmarkHint,
              ),
            ),
            const SizedBox(height: 8),
            KoryButton(
              label: l.actionSave,
              onPressed: () => Navigator.pop(context, (
                _address.text.trim(),
                _landmark.text.trim(),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
