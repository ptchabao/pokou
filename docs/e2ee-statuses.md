# Chiffrement de bout en bout des statuts

Les statuts texte, les légendes et les médias publiés par l'application sont
chiffrés sur l'appareil avant leur envoi. Le serveur ne reçoit jamais de texte
ou de légende en clair ; les fichiers photo/vidéo sont chiffrés avec
`MediaCipher` et téléversés comme `application/octet-stream` sous le nom opaque
`pokou.bin`. Chaque destinataire reçoit sa propre enveloppe créée avec
`E2EEService`. Aucun mécanisme cryptographique ni dépendance supplémentaire
n'a été introduit.

`GET /api/v1/status/audience` fournit les identifiants correspondant à
l'audience effective des règles de confidentialité et de découverte du fil.
La création recalcule cette audience et renvoie `409` si elle a changé depuis
le chiffrement côté client. Le serveur n'accepte ni champ texte en clair ni
média dont les marqueurs ne sont pas opaques. Il conserve une enveloppe E2EE
distincte pour chaque destinataire et ne sérialise que celle du lecteur ;
l'accès direct au média applique les mêmes règles et exige une enveloppe
destinataire.

Les enveloppes E2EE font avancer un ratchet et ne peuvent être ouvertes qu'une
fois. Le client conserve donc les statuts ouverts dans son cache SQLCipher avant
de les afficher à nouveau. L'auteur garde sa propre publication et la clé de
média dans ce cache local chiffré, puisqu'il ne peut pas ouvrir son propre
message ratchet d'envoi comme un message reçu. La copie auteur est liée à
l'appareil, comme le cache des messages déchiffrés.

La migration `0011` supprime les anciennes lignes de statut, leurs vues et
l'ancienne colonne texte avant d'activer le nouveau format. Les anciennes
publications ne sont pas réémises en clair.
