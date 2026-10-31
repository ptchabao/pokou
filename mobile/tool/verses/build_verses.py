"""Construit les versets embarqués des modules Pokou « Versets bibliques » et
« Versets coraniques », à partir de sources publiques (getbible.net,
alquran.cloud). Sortie : pokou/assets/verses/{bible,quran}_<langue>.json.

Usage : python3 tool/verses/build_verses.py assets/verses

Éditions — Bible, domaine public : Louis Segond 1910 (fr), King James (en),
Reina-Valera 1909 (es), Riveduta 1927 (it), Synodale 1876 (ru),
Smith-Van Dyck (ar). Coran : texte uthmani (ar) ; Pickthall (en) et
Krachkovsky (ru), domaine public ; Hamidullah (fr), Cortés (es) et Piccardo
(it), traductions de référence dont les droits sont à vérifier avant une
diffusion commerciale.

Chaque verset a été relu dans les six langues : numérotation des psaumes
(Synodale = Septante, Segond compte les titres), titres fondus dans le
verset 1, versets coraniques choisis pour se lire seuls."""
import json, os, sys, time, urllib.request

OUT = sys.argv[1]
CACHE = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'pokou_verse_cache')
os.makedirs(CACHE, exist_ok=True)

def get(url):
    key = os.path.join(CACHE, url.replace('/', '_').replace(':', '_'))
    if os.path.exists(key):
        return json.load(open(key))
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'pokou-verses-build'})
            data = json.load(urllib.request.urlopen(req, timeout=30))
            json.dump(data, open(key, 'w'))
            time.sleep(0.15)
            return data
        except Exception as e:
            print('retry', url, e, file=sys.stderr); time.sleep(2)
    raise SystemExit('échec ' + url)

# (livre, chapitre, premier verset, dernier verset) — numérotation hébraïque/KJV.
BIBLE = [
    (19,23,1,1),(43,3,16,16),(50,4,13,13),(20,3,5,6),(24,29,11,11),(23,41,10,10),
    (45,8,28,28),(40,11,28,28),(19,46,1,1),(6,1,9,9),(19,27,1,1),(23,40,31,31),
    (25,3,22,23),(46,13,4,4),(46,13,13,13),(40,6,33,33),(40,6,34,34),(50,4,6,6),
    (50,4,7,7),(19,37,5,5),(19,119,105,105),(43,14,27,27),(43,14,6,6),(43,8,12,12),
    (40,5,14,14),(40,7,7,7),(45,12,12,12),(45,15,13,13),(48,6,9,9),(49,2,8,8),
    (49,4,32,32),(51,3,23,23),(52,5,16,18),(55,1,7,7),(58,11,1,1),(58,13,5,5),
    (59,1,5,5),(60,5,7,7),(62,4,8,8),(62,4,18,18),(19,34,8,8),(19,55,22,22),
    (19,91,1,1),(19,103,2,2),(19,118,24,24),(19,121,1,2),(19,139,14,14),(20,16,3,3),
    (20,18,10,10),(21,3,1,1),(23,26,3,3),(23,43,2,2),(33,6,8,8),(36,3,17,17),
    (40,5,9,9),(40,28,20,20),(41,9,23,23),(42,1,37,37),(43,15,12,12),(43,16,33,33),
    (45,5,8,8),(47,5,17,17),
]
SYNODAL_SHIFT = {(20, 18): 1}
TITLE_SHIFT = {(19, 46): 1, (19, 34): 1, (19, 55): 1}
BIBLE_EDITIONS = {'fr':'ls1910','en':'kjv','es':'valera','it':'riveduta','ru':'synodal','ar':'arabicsv'}

def synodal_psalm(chapter, verse):
    """Psaumes hébreux → Septante (Synodale). 11–113 et 117–146 reculent
    d'un chapitre ; 9–10 fusionnent, 114–116 et 147 se découpent — aucun
    n'est dans la liste."""
    if 11 <= chapter <= 113 or 117 <= chapter <= 146:
        return chapter - 1
    return chapter

QURAN = [
    (94,5,5),(94,6,6),(13,28,28),(2,286,286),(65,3,3),(2,152,152),(1,2,2),
    (39,53,53),(2,186,186),(7,23,23),(20,114,114),(2,153,153),(2,156,156),
    (2,201,201),(3,8,8),(4,28,28),(6,162,162),(7,56,56),(9,51,51),(11,115,115),
    (12,86,86),(14,40,40),(16,97,97),(16,128,128),(17,80,80),(18,10,10),(20,25,26),
    (23,118,118),(25,63,63),(25,74,74),(28,24,24),(29,69,69),(33,41,42),(42,19,19),
    (2,269,269),(49,10,10),(49,13,13),(50,16,16),(51,56,56),(55,13,13),(64,11,11),
    (67,2,2),(73,8,8),(87,14,15),(93,3,3),(93,4,4),(93,5,5),(103,1,3),(112,1,4),
    (2,45,45),(3,31,31),(4,110,110),(2,115,115),(3,190,190),(8,2,2),(10,62,62),
    (11,6,6),(30,21,21),(15,49,49),(17,24,24),(21,107,107),(24,35,35),
]
QURAN_EDITIONS = {'ar':'quran-uthmani','fr':'fr.hamidullah','en':'en.pickthall','es':'es.cortes','it':'it.piccardo','ru':'ru.krachkovsky'}
QURAN_LABEL = {'fr':'Coran','en':'Quran','es':'Corán','it':'Corano','ru':'Коран','ar':'القرآن'}

# Titres de psaumes fondus dans le verset 1, et lettre hébraïque d'en-tête
# du psaume 119 : ce ne sont pas des paroles du verset.
PREFIXES = [
    'Cantique de David. ', 'De David. ', 'Cantique des degrés. ',
    'Salmo di Davide. ', 'Di Davide. ', 'Canto dei pellegrinaggi. ',
    'Per il Capo de’ musici. Dei figliuoli di Core. Per voci di fanciulle. Canto. ',
    'NUN. ',
]

def clean(text):
    for prefix in PREFIXES:
        if text.startswith(prefix):
            text = text[len(prefix):]
    # Reina-Valera 1909 : le premier mot d'un chapitre en capitales.
    first, _, rest = text.partition(' ')
    if len(first) > 1 and first.isupper():
        text = first.capitalize() + (' ' + rest if rest else '')
    return text

def bible():
    out = {lang: [] for lang in BIBLE_EDITIONS}
    for lang, edition in BIBLE_EDITIONS.items():
        for book, chapter, first, last in BIBLE:
            c = synodal_psalm(chapter, first) if (edition == 'synodal' and book == 19) else chapter
            data = get(f'https://api.getbible.net/v2/{edition}/{book}/{c}.json')
            verses = {v['verse']: v['text'].strip() for v in data['verses']}
            # Louis Segond et la Synodale comptent le titre de certains psaumes
            # comme verset 1 : le texte voulu est un verset plus loin.
            shift = TITLE_SHIFT.get((book, chapter), 0) if edition in ('ls1910', 'synodal') else 0
            shift += SYNODAL_SHIFT.get((book, chapter), 0) if edition == 'synodal' else 0
            text = ' '.join(verses[v + shift] for v in range(first, last + 1))
            # La référence dans la numérotation de l'édition affichée : un
            # lecteur de la Synodale connaît « Псалтирь 22 », pas « 23 ».
            ref = f"{data['book_name'].strip()} {c}:{first + shift}" + (f"-{last + shift}" if last != first else '')
            out[lang].append({'r': ref, 't': clean(' '.join(text.split()))})
    return out

def quran():
    out = {lang: [] for lang in QURAN_EDITIONS}
    editions = ','.join(QURAN_EDITIONS.values())
    for surah, first, last in QURAN:
        parts = {lang: [] for lang in QURAN_EDITIONS}
        names = None
        for ayah in range(first, last + 1):
            data = get(f'https://api.alquran.cloud/v1/ayah/{surah}:{ayah}/editions/{editions}')['data']
            for entry in data:
                lang = next(l for l, e in QURAN_EDITIONS.items() if e == entry['edition']['identifier'])
                parts[lang].append(' '.join(entry['text'].split()))
                names = (entry['surah']['englishName'], entry['surah']['name'])
        span = f"{surah}:{first}" + (f"-{last}" if last != first else '')
        for lang in QURAN_EDITIONS:
            name = names[1] if lang == 'ar' else names[0]
            item = {'r': f"{QURAN_LABEL[lang]} — {name} {span}", 't': ' '.join(parts[lang])}
            if lang != 'ar':
                item['ar'] = ' '.join(parts['ar'])
            out[lang].append(item)
    return out

if __name__ == '__main__':
    for kind, build in (('bible', bible), ('quran', quran)):
        result = build()
        for lang, items in result.items():
            path = os.path.join(OUT, f'{kind}_{lang}.json')
            json.dump(items, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
            print(kind, lang, len(items))
