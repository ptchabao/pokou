# Chiffrement des messages de groupe

Les messages de groupe sont chiffrés sur le téléphone avec Signal Sender Keys
(`libsignal_protocol_dart`). Le serveur ne reçoit que le chiffré, son epoch et
les métadonnées nécessaires au routage. Textes, citations, légendes, clés de
média et payloads sont inclus dans le chiffré. Les octets de pièces jointes et
leurs clés sont protégés par `MediaCipher`.

À chaque ajout ou retrait réel d'un membre, le serveur incrémente
`groups.crypto_epoch`. Les Sender Keys sont séparées par groupe, epoch et
expéditeur. Les anciennes distributions ne sont jamais remises aux nouveaux
membres; un message ou une distribution avec un epoch périmé est refusé. Avant
un envoi, le client enveloppe la distribution de sa Sender Key séparément pour
chaque membre actuel au moyen des sessions E2EE pairwise. Le serveur vérifie
que la liste des destinataires correspond exactement à l'appartenance actuelle.

Le cache de messages déchiffrés est la base SQLCipher de l'application. Le
cliquet Signal n'ouvre un message qu'une fois; le cache permet de le relire sans
réutiliser la clé. Un message illisible reste opaque et aucun chemin de repli en
clair n'existe. L'historique groupe enregistré avant cette migration a été
expurgé, car il ne pouvait pas être converti en chiffrement de bout en bout.

Les sondages, positions partagées et cartes de contact de groupe sont refusés
pour l'instant: leur modèle actuel stocke des données lisibles par le serveur.
Ils ne sont pas envoyés en clair; ils seront activés lorsqu'ils disposeront
d'un format E2EE.
