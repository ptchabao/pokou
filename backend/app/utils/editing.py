"""La fenêtre de modification d'un message — une seule valeur, un seul endroit.

Elle vivait recopiée dans trois fichiers (`messages.py`, `groups.py`,
`channels.py`), sous trois noms différents et deux formes différentes — un
`timedelta` ici, un entier de minutes là — avec un commentaire promettant
« la même promesse partout » et rien pour la tenir. Trois constantes qui
doivent s'accorder sans que rien ne le vérifie finissent toujours par
diverger, et l'écart ne se voit pas : un message de groupe modifiable plus
longtemps qu'un message privé ne casse rien, il ment simplement à
l'utilisateur sur ce qu'il a le droit de faire.
"""
from datetime import timedelta

#: Trois minutes.
#:
#: Le délai est court PAR CONCEPTION, et c'est le garde-fou de toute
#: conversation : sans lui, on pourrait réécrire après coup un engagement pris
#: il y a des semaines, que l'autre a déjà lu et sur lequel il a agi. Trois
#: minutes couvrent la faute de frappe qu'on voit juste après l'envoi — la
#: seule raison légitime de modifier — sans ouvrir la porte à la réécriture
#: de l'histoire.
MESSAGE_EDIT_WINDOW = timedelta(minutes=3)

#: Le même nombre, en minutes, pour les messages d'erreur destinés à
#: l'utilisateur. Dérivé et non recopié : c'est précisément la duplication
#: qui avait produit la divergence.
MESSAGE_EDIT_WINDOW_MINUTES = int(MESSAGE_EDIT_WINDOW.total_seconds() // 60)
