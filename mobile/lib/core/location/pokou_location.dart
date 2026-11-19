import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../api/api_client.dart';

/// La position du téléphone, demandée proprement — Assimé, Honam.
///
/// Si la localisation est coupée, ou refusée, on ne se contente plus d'un
/// message : une fenêtre explique pourquoi on la demande et ouvre les bons
/// réglages (localisation du système, ou autorisations de l'application).
/// `null` si la personne n'a pas donné sa position.
Future<Position?> obtainPosition(BuildContext context) async {
  final l = L.of(context);
  if (!await Geolocator.isLocationServiceEnabled()) {
    if (!context.mounted) return null;
    final open = await _ask(context, l.locOffTitle, l.locOffBody);
    if (open) await Geolocator.openLocationSettings();
    if (!await Geolocator.isLocationServiceEnabled()) return null;
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    if (!context.mounted) return null;
    final open = await _ask(context, l.locDeniedTitle, l.locDeniedBody);
    if (open) await Geolocator.openAppSettings();
    return null;
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  ).timeout(const Duration(seconds: 20));
}

Future<bool> _ask(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.of(context).actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.of(context).locOpenSettings),
          ),
        ],
      ),
    ) ??
    false;

/// Le nom du lieu (« Bè, Lomé ») d'une position, résolu par le serveur.
/// `null` si on ne le sait pas : l'appelant affiche alors « Près de toi »,
/// jamais des coordonnées.
Future<String?> placeLabel(ApiClient api, double lat, double lon) async {
  try {
    final response = await api
        .get('/geo/reverse?lat=$lat&lon=$lon')
        .timeout(const Duration(seconds: 8));
    final label = (response as Map<String, dynamic>)['label'];
    return label is String && label.trim().isNotEmpty ? label : null;
  } catch (_) {
    return null;
  }
}
