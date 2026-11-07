import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Réglages de l'app (Profil > Notifications / Économie de données).
///
/// Volontairement LOCAUX et non synchronisés côté serveur : « ne me notifie
/// pas ici » et « économise MES données » sont des propriétés de CET
/// appareil, pas du compte — les copier d'un téléphone à l'autre serait un
/// bug, pas une fonctionnalité.
///
/// Stockés dans le même coffre que le jeton d'accès (Keystore/Keychain via
/// flutter_secure_storage) plutôt que d'ajouter shared_preferences pour cinq
/// booléens.
/// REG-2 : ce qui se télécharge tout seul.
enum AutoDownload {
  none,
  photos,
  photosVideos,
  all;

  static AutoDownload parse(String? raw, AutoDownload fallback) =>
      AutoDownload.values.where((v) => v.name == raw).firstOrNull ?? fallback;
}

class AppSettings {
  const AppSettings({
    this.messageNotifications = true,
    this.groupNotifications = true,
    this.callNotifications = true,
    this.notificationSound = true,
    this.dataSaver = false,
    this.autoDownloadMobile = AutoDownload.none,
    this.autoDownloadWifi = AutoDownload.photos,
    this.callDataSaver = true,
    this.localeCode,
    this.phoneCountryIso,
    this.themeMode = ThemeMode.system,
  });

  final bool messageNotifications;
  final bool groupNotifications;
  final bool callNotifications;
  final bool notificationSound;

  /// Économie de données — les photos et vidéos reçues ne se téléchargent
  /// plus tout seules (voir media_bubble.dart) et les photos envoyées sont
  /// recompressées plus fort (voir _pickImageQuality).
  final bool dataSaver;

  /// REG-2 · Téléchargement automatique des médias reçus, selon le réseau.
  /// Par défaut : rien en données mobiles, les photos en Wi-Fi.
  final AutoDownload autoDownloadMobile;
  final AutoDownload autoDownloadWifi;

  /// REG-2 · Économiser les données pendant les appels : vidéo en qualité
  /// réduite, appel plus stable.
  final bool callDataSaver;

  /// Ce média peut-il se télécharger tout seul sur ce réseau ?
  bool autoDownloads({required String mimeType, required bool onWifi}) {
    if (dataSaver) return false;
    final rule = onWifi ? autoDownloadWifi : autoDownloadMobile;
    final isPhoto = mimeType.startsWith('image/');
    final isVideo = mimeType.startsWith('video/');
    return switch (rule) {
      AutoDownload.none => false,
      AutoDownload.photos => isPhoto,
      AutoDownload.photosVideos => isPhoto || isVideo,
      AutoDownload.all => true,
    };
  }

  /// Langue choisie explicitement (`fr`, `en`, `es`, `ru`, `ar`, `it`), ou
  /// `null` pour suivre le téléphone.
  ///
  /// `null` est une valeur à part entière, distincte de « français » : elle
  /// dit « suis mon téléphone », ce qui reste vrai si l'utilisateur change
  /// la langue de son appareil plus tard. Enregistrer « fr » au démarrage
  /// parce que le téléphone est en français figerait ce choix pour toujours.
  final String? localeCode;

  /// Clair, sombre, ou celui du téléphone.
  ///
  /// `system` par défaut : quelqu'un qui a réglé son téléphone en sombre l'a
  /// fait pour toutes ses applications, et lui redemander serait lui faire
  /// refaire un choix déjà exprimé. Le réglage existe quand même — beaucoup
  /// de gens veulent leur messagerie sombre sans passer tout le téléphone en
  /// sombre, ou l'inverse.
  final ThemeMode themeMode;

  /// Le pays du dernier numéro vérifié sur cet appareil (code ISO à deux
  /// lettres), ou `null` s'il n'y en a jamais eu.
  ///
  /// La locale de l'appareil est un mauvais indice du pays : un téléphone
  /// réglé en `fr_FR` et utilisé à Lomé propose la France. Le numéro déjà
  /// vérifié, lui, ne se trompe pas — c'est le seul endroit où
  /// l'application connaît le pays RÉEL de son utilisateur, sans permission
  /// ni requête.
  final String? phoneCountryIso;

  /// Qualité de compression passée à ImagePicker à l'envoi d'une photo.
  int get imageUploadQuality => dataSaver ? 55 : 85;

  AppSettings copyWith({
    bool? messageNotifications,
    bool? groupNotifications,
    bool? callNotifications,
    bool? notificationSound,
    bool? dataSaver,
    AutoDownload? autoDownloadMobile,
    AutoDownload? autoDownloadWifi,
    bool? callDataSaver,
    String? localeCode,
    String? phoneCountryIso,
    ThemeMode? themeMode,
    bool clearLocale = false,
  }) {
    return AppSettings(
      messageNotifications: messageNotifications ?? this.messageNotifications,
      groupNotifications: groupNotifications ?? this.groupNotifications,
      callNotifications: callNotifications ?? this.callNotifications,
      notificationSound: notificationSound ?? this.notificationSound,
      dataSaver: dataSaver ?? this.dataSaver,
      autoDownloadMobile: autoDownloadMobile ?? this.autoDownloadMobile,
      autoDownloadWifi: autoDownloadWifi ?? this.autoDownloadWifi,
      callDataSaver: callDataSaver ?? this.callDataSaver,
      // `clearLocale` explicite : sans lui, on ne pourrait jamais REVENIR à
      // la langue du téléphone, puisque passer `null` veut dire « ne change
      // pas » dans un copyWith.
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      phoneCountryIso: phoneCountryIso ?? this.phoneCountryIso,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'message_notifications': messageNotifications,
    'group_notifications': groupNotifications,
    'call_notifications': callNotifications,
    'notification_sound': notificationSound,
    'data_saver': dataSaver,
    'auto_download_mobile': autoDownloadMobile.name,
    'auto_download_wifi': autoDownloadWifi.name,
    'call_data_saver': callDataSaver,
    'locale_code': localeCode,
    'phone_country_iso': phoneCountryIso,
    'theme_mode': themeMode.name,
  };

  /// Chaque clé absente retombe sur son défaut : un réglage ajouté dans une
  /// version ultérieure ne casse pas les préférences déjà enregistrées.
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    messageNotifications: json['message_notifications'] as bool? ?? true,
    groupNotifications: json['group_notifications'] as bool? ?? true,
    callNotifications: json['call_notifications'] as bool? ?? true,
    notificationSound: json['notification_sound'] as bool? ?? true,
    dataSaver: json['data_saver'] as bool? ?? false,
    autoDownloadMobile: AutoDownload.parse(
      json['auto_download_mobile'] as String?,
      AutoDownload.none,
    ),
    autoDownloadWifi: AutoDownload.parse(
      json['auto_download_wifi'] as String?,
      AutoDownload.photos,
    ),
    callDataSaver: json['call_data_saver'] as bool? ?? true,
    localeCode: json['locale_code'] as String?,
    phoneCountryIso: json['phone_country_iso'] as String?,
    themeMode: _themeModeFrom(json['theme_mode'] as String?),
  );

  /// Une valeur inconnue — réglage écrit par une version future, fichier
  /// abîmé — retombe sur « suivre le téléphone » plutôt que de lever. Un
  /// réglage d'apparence ne doit jamais empêcher l'application de démarrer.
  static ThemeMode _themeModeFrom(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(const AppSettings()) {
    _load();
  }

  final FlutterSecureStorage _storage;

  static const _key = 'pokou_app_settings';

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      state = AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Coffre illisible ou JSON corrompu : on reste sur les défauts plutôt
      // que de bloquer le démarrage de l'app pour des préférences.
    }
  }

  Future<void> _persist(AppSettings next) async {
    // L'état est appliqué AVANT l'écriture : l'interrupteur doit réagir tout
    // de suite, et une écriture qui échoue ne doit pas figer l'écran.
    state = next;
    try {
      await _storage.write(key: _key, value: jsonEncode(next.toJson()));
    } catch (_) {}
  }

  Future<void> setMessageNotifications(bool value) =>
      _persist(state.copyWith(messageNotifications: value));
  Future<void> setGroupNotifications(bool value) =>
      _persist(state.copyWith(groupNotifications: value));
  Future<void> setCallNotifications(bool value) =>
      _persist(state.copyWith(callNotifications: value));
  Future<void> setNotificationSound(bool value) =>
      _persist(state.copyWith(notificationSound: value));
  Future<void> setDataSaver(bool value) =>
      _persist(state.copyWith(dataSaver: value));

  Future<void> setAutoDownload({
    required bool wifi,
    required AutoDownload value,
  }) => _persist(
    wifi
        ? state.copyWith(autoDownloadWifi: value)
        : state.copyWith(autoDownloadMobile: value),
  );

  Future<void> setCallDataSaver(bool value) =>
      _persist(state.copyWith(callDataSaver: value));

  Future<void> setThemeMode(ThemeMode value) =>
      _persist(state.copyWith(themeMode: value));

  /// Retient le pays d'un numéro vérifié, pour le proposer par défaut à la
  /// prochaine connexion sur cet appareil.
  Future<void> rememberPhoneCountry(String isoCode) =>
      _persist(state.copyWith(phoneCountryIso: isoCode));

  /// `null` remet la langue du téléphone.
  Future<void> setLocale(String? code) => _persist(
    code == null
        ? state.copyWith(clearLocale: true)
        : state.copyWith(localeCode: code),
  );
}

/// Gardé en vie pour toute la durée de l'app (pas `.autoDispose`) : les
/// réglages sont lus depuis PushService et depuis les bulles média, pas
/// seulement depuis l'écran de réglages.
final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController();
    });

/// Le téléphone est-il en Wi-Fi ? (REG-2). `false` tant qu'on ne sait pas :
/// mieux vaut ne pas télécharger en données mobiles par erreur.
final onWifiProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool wifi(List<ConnectivityResult> r) =>
      r.contains(ConnectivityResult.wifi) ||
      r.contains(ConnectivityResult.ethernet);
  try {
    yield wifi(await connectivity.checkConnectivity());
  } catch (_) {
    yield false;
  }
  yield* connectivity.onConnectivityChanged.map(wifi);
});
