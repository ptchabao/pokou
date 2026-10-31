import 'package:flutter/material.dart';

import '../../../core/widgets/contact_avatar.dart';
import '../data/channel_model.dart';

/// L'image d'une chaîne, partout où elle se montre.
///
/// Elle EXISTE depuis toujours — le modèle la porte, le serveur la sérialise,
/// l'en-tête de la chaîne l'affiche — mais les listes n'en tenaient aucun
/// compte : elles peignaient un porte-voix identique pour toutes. Une chaîne
/// qui s'est donné une identité visuelle ressemblait donc à toutes les
/// autres, précisément là où on choisit laquelle ouvrir.
///
/// S'appuie sur `ContactAvatar` plutôt que de refaire la résolution du
/// fichier : celle-ci met le résultat en cache dans son `State`, alors qu'un
/// `FutureBuilder` construit dans `build()` repart de zéro à chaque
/// reconstruction de la liste — l'image n'apparaîtrait jamais.
class ChannelAvatar extends StatelessWidget {
  const ChannelAvatar({super.key, required this.channel, this.size = 44});

  final PokouChannel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ContactAvatar(
      avatar: channel.avatar,
      displayName: channel.name,
      size: size,
      // Sans image, un porte-voix plutôt que l'initiale de la chaîne : c'est
      // ce qui la distingue d'un contact dans une liste mêlée.
      fallbackIcon: Icons.campaign_outlined,
    );
  }
}
