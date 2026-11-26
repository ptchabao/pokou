"""Les pages « projet » du site : Officine, Livreur, Kory.

Chacune explique le projet à qui il s'adresse et finit par l'inscription.
Les montants qui changent d'un pays à l'autre (prix de la course, frais
Kory+) sont lus dans la configuration du Togo au moment de la page : le site
ne contredit jamais ce que l'application affichera.
"""
import html
from typing import Optional

PLAY_URL = "https://play.google.com/store/apps/details?id=com.pokou.pokou"
OFFICINE_URL = "https://extranet.pokou.app/officine/"
CSS_VERSION = "20261127b"


def _fcfa(amount: Optional[int]) -> Optional[str]:
    if amount is None:
        return None
    return f"{amount:,}".replace(",", " ") + " F"


def _togo() -> dict:
    """La configuration du Togo, marché de lancement. Sans base, des
    valeurs vides : la page s'affiche quand même, sans montants."""
    try:
        from app.core.countries import country_config
        from app.core.database import SessionLocal

        db = SessionLocal()
        try:
            return country_config(db, "TG")
        finally:
            db.close()
    except Exception:
        return {}


_LOGOS = {
    "play": '<svg class="store__logo" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M22.018 13.298l-3.919 2.218-3.515-3.493 3.543-3.521 3.891 2.202a1.49 1.49 0 0 1 0 2.594zM1.337.924a1.486 1.486 0 0 0-.112.568v21.017c0 .217.045.419.124.6l11.155-11.087L1.337.924zm12.207 10.065l3.258-3.238L3.45.195a1.466 1.466 0 0 0-.946-.179l11.04 10.973zm0 2.067l-11 10.933c.298.036.612-.016.906-.183l13.324-7.54-3.23-3.21z"/></svg>',
}


def _header(active: str) -> str:
    def link(href: str, label: str, key: str) -> str:
        current = ' aria-current="page"' if key == active else ""
        return f'<a href="{href}"{current}>{label}</a>'

    return f"""
  <header class="nav">
    <div class="wrap nav__in">
      <a class="brand" href="/" aria-label="Pokou, accueil">
        <img class="brand__logo" src="/site/img/pokou-logotype.svg" alt="Pokou" width="118" height="35">
      </a>
      <nav class="nav__links" aria-label="Sections">
        {link("/#discussions", "Discussions", "")}
        {link("/kory", "Kory", "kory")}
        {link("/#honam", "Honam", "")}
        {link("/officine", "Officine", "officine")}
        {link("/livreur", "Livreur", "livreur")}
        {link("/#confidentialite", "Confidentialité", "")}
      </nav>
      <div class="nav__end">
        <a class="nav__link" href="{OFFICINE_URL}">Espace officine</a>
        <a class="btn btn--dark btn--sm" href="/#telecharger">Télécharger</a>
      </div>
    </div>
  </header>"""


_FOOTER = f"""
  <footer class="foot">
    <div class="wrap foot__grid">
      <div class="foot__brand">
        <a class="brand" href="/" aria-label="Pokou, accueil"><img class="brand__logo" src="/site/img/pokou-logotype.svg" alt="Pokou" width="108" height="32"></a>
        <p>La messagerie et les services du quotidien, pensés depuis l'Afrique.</p>
      </div>
      <nav aria-label="Pokou"><h4>Pokou</h4><a href="/#discussions">Discussions</a><a href="/kory">Kory</a><a href="/#honam">Honam</a><a href="/#assime">Assimé</a></nav>
      <nav aria-label="Rejoindre"><h4>Rejoindre</h4><a href="/officine">Inscrire mon officine</a><a href="/livreur">Devenir livreur</a><a href="{OFFICINE_URL}">Espace officine</a></nav>
      <nav aria-label="Aide"><h4>Aide</h4><a href="mailto:support@pokou.app">support@pokou.app</a><a href="/compte/suppression/">Supprimer mon compte</a></nav>
      <nav aria-label="Légal"><h4>Légal</h4><a href="/conditions">Conditions d'utilisation</a><a href="/confidentialite">Confidentialité</a></nav>
    </div>
    <div class="wrap foot__bottom">
      <span>© 2026 Pokou</span>
      <span>Nos racines. Nos liens. Notre avenir.</span>
    </div>
  </footer>"""


def head_tags(title: str, description: str, path: str, ld: Optional[dict] = None) -> str:
    """Les balises de référencement communes à toutes les pages du site."""
    import json

    url = f"https://pokou.app{path}"
    t, d = html.escape(title), html.escape(description)
    data = f'\n  <script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>' if ld else ""
    return f"""<meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{t}</title>
  <meta name="description" content="{d}">
  <meta name="robots" content="index, follow, max-image-preview:large">
  <link rel="canonical" href="{url}">
  <meta name="theme-color" content="#FFFFFF">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Pokou">
  <meta property="og:locale" content="fr_FR">
  <meta property="og:url" content="{url}">
  <meta property="og:title" content="{t}">
  <meta property="og:description" content="{d}">
  <meta property="og:image" content="https://pokou.app/site/img/partage.jpg">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{t}">
  <meta name="twitter:description" content="{d}">
  <meta name="twitter:image" content="https://pokou.app/site/img/partage.jpg">
  <link rel="icon" href="/favicon.ico" sizes="48x48">
  <link rel="icon" href="/site/img/favicon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/site/img/apple-touch-icon.png">
  <link rel="manifest" href="/site.webmanifest">
  <link rel="preload" href="/site/fonts/inter-latin.woff2" as="font" type="font/woff2" crossorigin>
  <link rel="stylesheet" href="/site/site.css?v={CSS_VERSION}">{data}"""


def _faq_ld(body: str) -> Optional[dict]:
    """Les questions fréquentes de la page, en données structurées
    (FAQPage) : Google peut les afficher directement dans ses résultats."""
    import re

    pairs = re.findall(r"<details><summary>(.*?)</summary><p>(.*?)</p></details>", body, re.S)
    if not pairs:
        return None
    return {"@context": "https://schema.org", "@type": "FAQPage", "mainEntity": [
        {"@type": "Question", "name": html.unescape(q),
         "acceptedAnswer": {"@type": "Answer", "text": html.unescape(a)}} for q, a in pairs]}


def _page(title: str, description: str, active: str, body: str) -> str:
    return f"""<!doctype html>
<html lang="fr">
<head>
  {head_tags(title, description, "/" + active, _faq_ld(body))}
</head>
<body>
<!--email_off-->{_header(active)}
  <main>{body}
  </main>{_FOOTER}
<!--/email_off-->
</body>
</html>"""


def _steps(items: list[tuple[str, str]]) -> str:
    cells = "".join(
        f'<article class="step"><span class="step__n">{i}</span><div><h3>{html.escape(t)}</h3>'
        f"<p>{html.escape(d)}</p></div></article>"
        for i, (t, d) in enumerate(items, 1)
    )
    return f'<div class="steps steps--{len(items)}">{cells}</div>'


def _faq(items: list[tuple[str, str]]) -> str:
    rows = "".join(
        f"<details><summary>{html.escape(q)}</summary><p>{html.escape(a)}</p></details>" for q, a in items
    )
    return f'<div class="faq">{rows}</div>'


def _cta(title: str, text: str, primary: tuple[str, str], secondary: Optional[tuple[str, str]] = None) -> str:
    second = (f'<a class="btn btn--ghost" href="{secondary[1]}">{secondary[0]}</a>' if secondary else "")
    return f"""
    <section class="hero-shell">
      <div class="cta mesh mesh--warm">
        <h2>{title}</h2>
        <p>{text}</p>
        <div class="row row--center"><a class="btn btn--dark" href="{primary[1]}" rel="noopener">{primary[0]}</a>{second}</div>
      </div>
    </section>"""


def _store_button() -> str:
    return (f'<a class="store" href="{PLAY_URL}" rel="noopener">{_LOGOS["play"]}'
            '<span class="store__text"><small>Disponible sur</small>Google Play</span></a>')


# ── Officine ────────────────────────────────────────────────────────────────

def officine_page() -> str:
    body = f"""
    <section class="hero-shell">
      <div class="hero hero--page mesh mesh--warm">
        <div class="hero__text">
          <span class="pill"><i class="ico ico--honam" aria-hidden="true"></i>Honam · pour les pharmacies</span>
          <h1>Votre officine, à portée de tout le quartier.</h1>
          <p class="lead">Recevez les ordonnances des patients proches, envoyez un devis en quelques gestes, encaissez par mobile money et faites livrer par un coursier Pokou. Sans site à créer, sans caisse à changer.</p>
          <div class="row">
            <a class="btn btn--dark" href="#inscription">Inscrire mon officine</a>
            <a class="btn btn--ghost" href="{OFFICINE_URL}">Déjà inscrite ? Espace officine</a>
          </div>
        </div>
        <div class="hero__visual hero__visual--shot" aria-hidden="true">
          <img class="phone" src="/site/img/app/honam.jpg" alt="" width="390" height="844">
          <div class="chip chip--b"><span class="chip__dot chip__dot--green"></span>Nouvelle ordonnance</div>
          <div class="chip chip--c"><span class="chip__dot chip__dot--gold"></span>Devis payé · 8 400 F</div>
        </div>
      </div>
    </section>

    <section class="section" id="comment">
      <div class="wrap">
        <span class="caps center-block">Comment ça marche</span>
        <h2 class="center">De l'ordonnance à la livraison.</h2>
        {_steps([
            ("Le patient envoie son ordonnance", "Il la photographie dans Pokou et choisit votre officine parmi les pharmacies proches."),
            ("Vous répondez par un devis", "Médicaments disponibles, prix, et course de livraison : le patient voit le total avant de payer."),
            ("Le patient paie depuis son wallet", "Le paiement mobile money est confirmé dans votre espace. Vous préparez la commande."),
            ("Un coursier livre, contre un code", "Vous demandez un coursier Pokou ; la livraison est confirmée par le code que le patient remet."),
        ])}
      </div>
    </section>

    <section class="band mesh mesh--sunset">
      <div class="wrap split">
        <div class="split__text">
          <span class="caps caps--light">Ce que vous y gagnez</span>
          <h2>Plus de patients, moins d'appels manqués.</h2>
          <ul class="ticks ticks--light">
            <li>Les patients du quartier vous trouvent, même quand ils ne peuvent pas se déplacer.</li>
            <li>Les ordonnances arrivent écrites, lisibles, avec le numéro du patient.</li>
            <li>Plusieurs téléphones au comptoir : toute l'équipe reçoit les commandes.</li>
            <li>Vos gardes et vos fermetures temporaires s'affichent automatiquement.</li>
            <li>Des factures pour votre comptabilité, et l'historique des commandes.</li>
          </ul>
        </div>
        <div class="split__visual">
          <div class="window" aria-hidden="true">
            <div class="window__bar"><i></i><i></i><i></i></div>
            <div class="window__body">
              <div class="flow__head"><strong>Aujourd'hui</strong><span>Pharmacie du Marché</span></div>
              <ol class="flow">
                <li class="done">12 ordonnances reçues<small>9 devis envoyés</small></li>
                <li class="done">7 commandes payées<small>mobile money</small></li>
                <li class="now">2 coursiers en route<small>livraison sous 30 min</small></li>
              </ol>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section class="section" id="inscription">
      <div class="wrap">
        <h2 class="center">Deux formules, au choix.</h2>
        <p class="center lead lead--narrow">Les prix de votre pays sont affichés dans l'application, hors taxes et TVA comprise, avant tout paiement.</p>
        <div class="plans plans--2">
          <article class="plan">
            <h3>Wétri</h3>
            <p class="plan__price">Abonnement mensuel</p>
            <ul><li>Ordonnances et devis illimités</li><li>Paiement mobile money</li><li>Coursiers Pokou à la demande</li><li>Sans engagement : un mois à la fois</li></ul>
          </article>
          <article class="plan plan--accent">
            <span class="plan__tag">Le plus avantageux</span>
            <h3>Épé</h3>
            <p class="plan__price">Abonnement annuel</p>
            <ul><li>Tout Wétri, pour l'année</li><li>Un seul paiement</li><li>Moins cher que douze mois de Wétri</li></ul>
          </article>
        </div>
        <div class="howto">
          <h3>S'inscrire en quatre étapes</h3>
          <ol>
            <li>Installez Pokou et créez votre compte avec le numéro de l'officine.</li>
            <li>Dans « Plus », ouvrez « Espace officine » puis « Référencer votre officine ».</li>
            <li>Renseignez le nom, l'adresse, le n° d'autorisation d'exercice et l'autorisation d'ouverture.</li>
            <li>Choisissez Wétri ou Épé : l'officine apparaît aux patients dès la validation par l'équipe Pokou.</li>
          </ol>
          <div class="row">{_store_button()}<a class="btn btn--ghost" href="mailto:support@pokou.app?subject=Inscription%20officine">Être rappelé</a></div>
        </div>
      </div>
    </section>

    <section class="section section--tight">
      <div class="wrap narrow">
        <h2 class="center">Questions fréquentes</h2>
        {_faq([
            ("Qui peut s'inscrire ?", "Les pharmacies autorisées dans leur pays. L'équipe Pokou vérifie l'autorisation avant d'ouvrir l'officine aux patients."),
            ("Les médicaments sur ordonnance sont-ils contrôlés ?", "Oui : un médicament sur ordonnance n'est délivré que sur présentation de l'ordonnance, sous la responsabilité du pharmacien. L'original est récupéré à la livraison quand il le faut."),
            ("Qui paie le coursier ?", "La course est comprise dans le devis payé par le patient. L'officine verse au coursier le prix de la course sur son wallet."),
            ("Faut-il un ordinateur ?", "Non. Tout se fait depuis l'application ; l'espace officine en ligne est un plus pour le comptoir."),
        ])}
      </div>
    </section>
    {_cta("Ouvrez votre comptoir à tout le quartier.", "L'inscription prend quelques minutes depuis l'application.", ("Inscrire mon officine", PLAY_URL), ("Espace officine", OFFICINE_URL))}"""
    return _page("Pokou pour les pharmacies – Honam",
                 "Recevez les ordonnances des patients proches, envoyez un devis, encaissez par mobile money et faites livrer par un coursier Pokou.",
                 "officine", body)


# ── Livreur ────────────────────────────────────────────────────────────────

def livreur_page() -> str:
    togo = _togo()
    ride = _fcfa(togo.get("delivery_price"))
    earn = f"{ride} par course au Togo" if ride else "le prix de la course, payé par l'officine"
    body = f"""
    <section class="hero-shell">
      <div class="hero hero--page mesh mesh--warm">
        <div class="hero__text">
          <span class="pill"><i class="ico ico--coursier" aria-hidden="true"></i>Honam · devenir livreur</span>
          <h1>Gagne de l'argent en livrant près de chez toi.</h1>
          <p class="lead">Livre les médicaments des pharmacies de ton quartier, à moto, à vélo ou à pied. Tu choisis tes courses, l'officine te paie sur ton wallet.</p>
          <div class="row">
            <a class="btn btn--dark" href="#inscription">Devenir livreur</a>
            <a class="btn btn--ghost" href="#comment">Comment ça marche</a>
          </div>
        </div>
        <div class="hero__visual hero__visual--card" aria-hidden="true">
          <div class="earn">
            <span class="earn__label">Tu gagnes</span>
            <strong class="earn__amount">{html.escape(ride or "—")}</strong>
            <span class="earn__sub">par course · payé par l'officine</span>
            <div class="earn__rows">
              <span>Courses d'essai</span><b>5, sans commission</b>
              <span>Moto</span><b>jusqu'à 8 km</b>
              <span>Vélo</span><b>jusqu'à 4 km</b>
              <span>À pied</span><b>jusqu'à 1,5 km</b>
            </div>
          </div>
          <div class="chip chip--a chip--plain"><span class="chip__dot chip__dot--green"></span>Course acceptée</div>
          <div class="chip chip--c"><span class="chip__dot chip__dot--gold"></span>Livraison confirmée · code 4821</div>
        </div>
      </div>
    </section>

    <section class="section" id="comment">
      <div class="wrap">
        <span class="caps center-block">Comment ça marche</span>
        <h2 class="center">Une course, quatre étapes.</h2>
        {_steps([
            ("Une officine demande un coursier", "Tu reçois la course si elle est à ta portée : adresse, distance et prix affichés."),
            ("Tu acceptes et tu récupères", "La commande t'attend au comptoir, prête et payée par le patient."),
            ("Tu livres le patient", "Il te remet son code de livraison : la course est confirmée tout de suite."),
            ("L'officine te paie", f"Sur ton wallet mobile money : {earn}."),
        ])}
      </div>
    </section>

    <section class="band band--gold">
      <div class="wrap split">
        <div class="split__text">
          <h2>Ce qu'il te faut.</h2>
          <ul class="ticks">
            <li>Avoir 18 ans ou plus.</li>
            <li>Une moto, un vélo, ou de bonnes jambes pour les courses à pied.</li>
            <li>Un téléphone Android avec Pokou et un wallet mobile money.</li>
            <li>Une pièce d'identité, vérifiée par l'équipe Pokou.</li>
          </ul>
          <img class="phone phone--inline" src="/site/img/app/livraison.jpg" alt="Le suivi d'une livraison dans Pokou : le coursier en route et le code de remise." width="390" height="844" loading="lazy">
        </div>
        <div class="split__text">
          <h2>Ce que ça coûte.</h2>
          <ul class="ticks">
            <li>Un mois d'essai avec 5 courses, sans commission.</li>
            <li>Ensuite : l'adhésion Win Pokou et un pack de courses payé d'avance.</li>
            <li>Le pack se choisit selon ton rythme : de 5 courses à illimité.</li>
            <li>Pendant la période de lancement d'un pays, tu livres sans adhésion ni pack.</li>
          </ul>
        </div>
      </div>
    </section>

    <section class="section" id="inscription">
      <div class="wrap">
        <div class="howto howto--center">
          <h3>S'inscrire en quelques minutes</h3>
          <ol>
            <li>Installe Pokou et connecte-toi avec ton numéro.</li>
            <li>Dans l'onglet Honam, touche « Devenir coursier ».</li>
            <li>Indique ta date de naissance, ta ville, ton moyen de transport et ton wallet.</li>
            <li>Réponds au petit quiz : ta candidature part à l'équipe Pokou.</li>
          </ol>
          <div class="row row--center">{_store_button()}</div>
        </div>
      </div>
    </section>

    <section class="section section--tight">
      <div class="wrap narrow">
        <h2 class="center">Questions fréquentes</h2>
        {_faq([
            ("Je peux livrer quand je veux ?", "Oui. Tu te mets disponible quand tu veux, et tu acceptes seulement les courses qui t'arrangent."),
            ("Qui me paie, et quand ?", "L'officine te verse le prix de la course sur ton wallet. Un paiement en retard se signale depuis la course."),
            ("Que se passe-t-il en cas de problème ?", "Un retard ou une livraison manquée se signale dans l'application. Trois défauts entraînent une suspension, pour protéger les patients."),
            ("Je peux inviter un ami ?", "Oui : ton code de parrainage lui offre des courses simples pour commencer, et toi des courses offertes à sa première livraison."),
        ])}
      </div>
    </section>
    {_cta("Livre pour ton quartier.", "Rejoins les coursiers Pokou depuis l'application.", ("Devenir livreur", PLAY_URL))}"""
    return _page("Devenir livreur Pokou – Honam",
                 "Gagne de l'argent en livrant les médicaments des pharmacies de ton quartier, à moto, à vélo ou à pied.",
                 "livreur", body)


# ── Kory ───────────────────────────────────────────────────────────────────

def kory_page() -> str:
    fee = _fcfa(_togo().get("kory_plus_fee_ht"))
    fee_text = f"{fee} HT par membre au Togo" if fee else "des frais d'ouverture par membre"
    body = f"""
    <section class="hero-shell">
      <div class="hero hero--page mesh mesh--warm">
        <div class="hero__text">
          <span class="pill"><i class="ico ico--kory" aria-hidden="true"></i>Kory · cagnottes, tontines, cotisations</span>
          <h1>Cotiser ensemble, sur la parole donnée.</h1>
          <p class="lead">Organise une cagnotte pour un anniversaire, une tontine entre collègues ou la cotisation de la famille. Chacun s'engage, Kory suit les échéances et tient le journal. L'argent, lui, ne passe jamais par Pokou.</p>
          <div class="row">
            <a class="btn btn--dark" href="#commencer">Créer une cagnotte</a>
            <a class="btn btn--ghost" href="#comment">Comment ça marche</a>
          </div>
        </div>
        <div class="hero__visual hero__visual--shot" aria-hidden="true">
          <img class="phone" src="/site/img/app/kory.jpg" alt="" width="390" height="844">
          <div class="chip chip--b"><span class="chip__dot chip__dot--gold"></span>Tontine · tour 4 sur 10</div>
          <div class="chip chip--c"><span class="chip__dot chip__dot--green"></span>Ta part est confirmée</div>
        </div>
      </div>
    </section>

    <section class="section" id="comment">
      <div class="wrap">
        <span class="caps center-block">Trois façons de cotiser</span>
        <h2 class="center">Pour chaque occasion.</h2>
        <div class="plans">
          <article class="plan"><h3>Cagnotte</h3><p class="plan__price">Un objectif, une date</p>
            <ul><li>Anniversaire, mariage, funérailles, projet</li><li>Chacun verse ce qu'il veut</li><li>La barre avance à chaque contribution confirmée</li></ul></article>
          <article class="plan plan--accent"><span class="plan__tag">Kory+</span><h3>Tontine</h3><p class="plan__price">Chacun son tour</p>
            <ul><li>Un montant fixe par tour</li><li>L'ordre des bénéficiaires tiré au sort</li><li>Rappels avant chaque échéance</li></ul></article>
          <article class="plan"><h3>Cotisation</h3><p class="plan__price">Régulière</p>
            <ul><li>Chaque semaine, quinzaine ou mois</li><li>Pour l'association, la famille, le quartier</li><li>Qui est à jour, d'un coup d'œil</li></ul></article>
        </div>
      </div>
    </section>

    <section class="band mesh mesh--sunset">
      <div class="wrap split">
        <div class="split__visual">
          <div class="orb"><img src="/site/img/app/kory.jpg" alt="L'onglet Kory : cagnottes, tontines et cotisations." width="390" height="844" loading="lazy"></div>
        </div>
        <div class="split__text">
          <span class="caps caps--light">Pokou ne touche pas l'argent</span>
          <h2>Wallet à wallet, sans intermédiaire.</h2>
          <ul class="ticks ticks--light">
            <li>Chacun verse directement au collecteur, depuis son wallet mobile money.</li>
            <li>Le collecteur confirme ce qu'il reçoit : tout le monde voit le total confirmé.</li>
            <li>Aucune commission sur les cagnottes et les tontines.</li>
            <li>L'activité de la collecte s'affiche dans la discussion du groupe.</li>
          </ul>
        </div>
      </div>
    </section>

    <section class="section" id="commencer">
      <div class="wrap">
        <div class="howto howto--center">
          <h3>Lancer une collecte</h3>
          <ol>
            <li>Ouvre l'onglet Kory dans Pokou et touche « Créer ».</li>
            <li>Choisis cagnotte, tontine ou cotisation, le montant et la date.</li>
            <li>Ajoute les participants depuis tes contacts, ou partage le lien d'invitation.</li>
            <li>Suis les contributions : Kory relance ceux qui sont en retard.</li>
          </ol>
          <p class="note">Kory+ (tontines avancées) : {html.escape(fee_text)}, affichés avant le paiement.</p>
          <div class="row row--center">{_store_button()}</div>
        </div>
      </div>
    </section>

    <section class="section section--tight">
      <div class="wrap narrow">
        <h2 class="center">Questions fréquentes</h2>
        {_faq([
            ("Pokou garde-t-il l'argent ?", "Non, jamais. Les versements vont directement d'un wallet à l'autre. Kory tient seulement le journal de ce que chacun annonce et de ce que le collecteur confirme."),
            ("Et si quelqu'un ne paie pas ?", "Kory envoie des rappels avant et après l'échéance. Un désaccord se règle entre les membres et le collecteur, avec le journal comme référence."),
            ("Qui voit les montants ?", "Les membres de la collecte. Le collecteur peut masquer les montants individuels et n'afficher que le total."),
            ("Que devient une collecte terminée ?", "Elle passe dans les archives, consultables à tout moment, sans encombrer l'onglet."),
        ])}
      </div>
    </section>
    {_cta("Ensemble, plus forts.", "Crée ta première cagnotte en une minute.", ("Créer une cagnotte", PLAY_URL))}"""
    return _page("Kory – cagnottes et tontines | Pokou",
                 "Cagnottes, tontines et cotisations entre proches. Chacun verse depuis son wallet : Pokou ne touche pas l'argent.",
                 "kory", body)


PAGES = {"officine": officine_page, "livreur": livreur_page, "kory": kory_page}
