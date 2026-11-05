# Chiffrement de bout en bout des appels de groupe

Les appels audio/vidéo de groupe utilisent la clé d'appel éphémère existante
(`CallKey`) et le chemin E2EE de LiveKit. Ils ne réutilisent pas le chiffrement
des messages et n'introduisent aucun nouvel algorithme.

## Création et accès

- L'appelant génère une clé aléatoire de 32 octets par salon.
- Avant de demander un jeton LiveKit, le mobile vérifie que chaque membre visé
  annonce `call-v1`, possède une session E2EE établie avec l'identité publiée
  actuelle, puis scelle la même clé séparément pour chaque destinataire.
- Un appel démarré depuis un groupe transmet une enveloppe par membre ; le
  serveur ne conserve que les enveloppes des personnes que les règles d'appel
  autorisent à faire sonner.
- Le serveur refuse la création d'un appel de groupe si une clé manque. Les
  appels de groupe par `contact_ids` suivent la même règle. Les appels 1:1
  gardent leur comportement antérieur, y compris leur mode non chiffré si les
  deux appareils ne peuvent pas encore utiliser E2EE.
- Pour accepter, rejoindre un appel actif ou revenir après une déconnexion,
  l'application ouvre l'enveloppe individuelle puis configure LiveKit avec la
  clé. Une appartenance au groupe ou la connaissance du nom du salon ne donne
  pas accès à la clé.
- Une invitation dynamique est acceptée uniquement si l'appel est déjà
  chiffré et si l'invitant peut sceller la clé pour chaque nouvel invité.
  Une session 1:1 non chiffrée ne peut pas être transformée à chaud en appel
  de groupe : LiveKit ne permettrait pas de donner rétroactivement la nouvelle
  clé aux personnes déjà connectées.

Toute clé manquante, session indisponible, erreur d'ouverture ou détection
d'une piste LiveKit non chiffrée interrompt le chemin d'appel concerné ; il
n'existe pas de repli silencieux vers un appel de groupe en clair.

## Données côté serveur

`CallParticipant.sealed_key` contient uniquement l'enveloppe E2EE opaque
(`encryption`, `ciphertext`, `envelope`) et l'identifiant de l'expéditeur
nécessaire à la sélection de session. Le serveur ne reçoit pas la clé d'appel
en clair. Cette donnée est attachée au participant afin qu'il puisse la
récupérer lorsqu'il rejoint ou rejoint de nouveau le salon.

Le chiffrement des pistes audio/vidéo est fourni par LiveKit E2EE avec cette
clé partagée. Les événements de signalisation, les identifiants des
participants et les métadonnées de l'appel ne sont pas chiffrés de bout en
bout.
