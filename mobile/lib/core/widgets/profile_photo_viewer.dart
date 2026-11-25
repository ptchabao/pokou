import 'package:flutter/material.dart';

import '../media/media_repository.dart' show MediaMeta;
import '../platform/secure_screen.dart';
import 'image_viewer.dart';
import 'media_image.dart';

/// Une photo de profil (ou de groupe) en plein écran, sans capture d'écran
/// possible le temps de l'affichage : `FLAG_SECURE` sur Android, par le
/// même canal que la vue unique (voir SecureScreen). iOS n'a pas
/// d'équivalent.
Future<void> openProfilePhoto(
  BuildContext context, {
  required MediaMeta avatar,
  String? title,
}) async {
  await SecureScreen.acquire();
  try {
    if (!context.mounted) return;
    await ImageViewer.open(
      context,
      images: [
        ViewerImage(
          full: MediaImage.meta(avatar, fit: BoxFit.contain),
          title: title,
        ),
      ],
    );
  } finally {
    await SecureScreen.release();
  }
}
