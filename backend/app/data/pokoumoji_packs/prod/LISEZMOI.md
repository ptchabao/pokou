# Pack Pokoumoji de production

Vide tant que la marque n'a validé aucun visuel (catalogue V1.3 : toutes les
entrées sont `a_produire`).

Pour publier : déposer les WebP validés aux chemins du catalogue
(`64|128|256/assets/<catégorie>/<id>.webp`), puis signer avec la clé de
production — `python tools/pokoumoji/signer_pack.py backend/app/data/pokoumoji_packs/prod`.
Passer les entrées correspondantes à `approved` dans
`mobile/assets/pokoumoji/catalogue.json` (sinon l'application les masque).
