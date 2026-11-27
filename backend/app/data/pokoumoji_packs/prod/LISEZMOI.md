# Pack Pokoumoji de production

Décision de la marque (27 novembre 2026) : en attendant les visuels
définitifs, ce pack reprend les dessins des planches de référence
(329 emojis et stickers découpés, fond transparent), signés avec la clé
de PRODUCTION. Les entrées sans dessin ne sont pas publiées. Une entrée contenue
dans ce pack signé est montrée par l'application, même si le catalogue la
dit encore `a_produire`.

Pour remplacer les images : déposer les WebP validés aux mêmes chemins
(`64|128|256/assets/<catégorie>/<id>.webp`, 100 Ko au plus, carrés à la
taille du dossier), puis signer :

    python tools/pokoumoji/signer_pack.py backend/app/data/pokoumoji_packs/prod

La clé privée est hors du dépôt (`~/.pokoumoji/pokoumoji_prod_ed25519.pem`).
Les téléphones prennent le nouveau manifeste au prochain lancement : aucune
nouvelle version de l'application n'est nécessaire.
