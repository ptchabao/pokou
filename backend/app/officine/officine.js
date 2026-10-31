// Honam — espace officine (application web installable, BM-08).
//
// Aucun texte venu du serveur n'est inséré comme HTML : tout passe par
// `el()` et `textContent`. Une ordonnance, un nom de patient ou un motif de
// refus ne peuvent donc pas injecter de script.
"use strict";

const API = "/api/v1";
const STATUS = {
  SUBMITTED: ["Nouvelle ordonnance", "info"],
  QUOTED: ["Devis envoyé", "warning"],
  ACCEPTED: ["Devis accepté, paiement attendu", "warning"],
  PAID: ["Payée, à préparer", "success"],
  READY: ["Prête, coursier attendu", "info"],
  IN_DELIVERY: ["En livraison", "info"],
  DELIVERED: ["Livrée", "success"],
  REJECTED: ["Refusée", "danger"],
  EXPIRED: ["Devis expiré", "danger"],
  CANCELLED: ["Annulée", "danger"],
};
const TABS = [
  ["", "À traiter"], ["SUBMITTED", "Nouvelles"], ["ACCEPTED", "Paiement"], ["PAID", "À préparer"],
  ["READY", "Prêtes"], ["DELIVERED", "Livrées"],
];

let access = null;
const app = document.getElementById("app");
const logoutButton = document.getElementById("logout");

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (key === "on") for (const [ev, fn] of Object.entries(value)) node.addEventListener(ev, fn);
    else if (key === "class") node.className = value;
    else if (value !== false && value != null) node.setAttribute(key, value === true ? "" : value);
  }
  for (const child of children.flat()) {
    if (child == null || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

const fcfa = (n) => n == null ? "—" : `${new Intl.NumberFormat("fr-FR").format(n)} FCFA`;
const when = (iso) => iso ? new Date(iso + (iso.endsWith("Z") ? "" : "Z")).toLocaleString("fr-FR") : "";
const pill = (status) => {
  const [label, tone] = STATUS[status] || [status, "info"];
  return el("span", { class: `pill ${tone}` }, label);
};

function render(...nodes) {
  app.replaceChildren(...nodes);
  window.scrollTo(0, 0);
}

function errorBox(message) {
  return el("p", { class: "error", role: "alert" }, "⚠ ", message);
}

// ── Session ──────────────────────────────────────────────────────────────
// Le jeton d'accès reste en mémoire ; le jeton de rafraîchissement est
// gardé dans le navigateur pour qu'une officine ne refasse pas un SMS toutes
// les 30 minutes. La page n'exécute que son propre script (CSP du serveur).

async function refresh() {
  const token = localStorage.getItem("honam.refresh");
  if (!token) return false;
  const r = await fetch(`${API}/auth/refresh`, { method: "POST", headers: { Authorization: `Bearer ${token}` } });
  if (!r.ok) { localStorage.removeItem("honam.refresh"); return false; }
  const body = await r.json();
  access = body.access_token;
  localStorage.setItem("honam.refresh", body.refresh_token);
  return true;
}

async function api(path, { method = "GET", body, raw = false } = {}) {
  const run = () => fetch(`${API}${path}`, {
    method,
    headers: { ...(access ? { Authorization: `Bearer ${access}` } : {}), ...(body ? { "Content-Type": "application/json" } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let r = await run();
  if (r.status === 401 && await refresh()) r = await run();
  if (r.status === 401) { showLogin(); throw new Error("Session expirée"); }
  if (raw) return r;
  const data = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(typeof data.detail === "string" ? data.detail : "L'opération n'a pas abouti.");
  return data;
}

function showLogin(message) {
  logoutButton.hidden = true;
  const phone = el("input", { id: "phone", type: "tel", autocomplete: "tel", placeholder: "+228 90 00 00 00", required: true });
  const code = el("input", { id: "code", inputmode: "numeric", autocomplete: "one-time-code", maxlength: "6" });
  const status = el("div");
  const codeBlock = el("div", { hidden: true }, el("label", { for: "code" }, "Code reçu par SMS"), code,
    el("button", { class: "primary mt", on: { click: verify } }, "Se connecter"));
  async function request() {
    status.replaceChildren();
    const r = await fetch(`${API}/auth/phone/request-otp`, {
      method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ phone: phone.value.trim() }),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok) return status.append(errorBox(data.detail || "Numéro invalide."));
    codeBlock.hidden = false;
    code.focus();
  }
  async function verify() {
    status.replaceChildren();
    const r = await fetch(`${API}/auth/phone/verify-otp`, {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phone: phone.value.trim(), code: code.value.trim() }),
    });
    const data = await r.json().catch(() => ({}));
    if (!r.ok || !data.access_token) return status.append(errorBox(data.detail || "Code incorrect."));
    access = data.access_token;
    localStorage.setItem("honam.refresh", data.refresh_token);
    showDashboard();
  }
  render(
    el("h1", {}, "Espace officine"),
    el("div", { class: "card" },
      el("p", { class: "muted" }, "Connectez-vous avec le numéro du pharmacien titulaire ou d'un collaborateur."),
      message ? errorBox(message) : null,
      el("label", { for: "phone" }, "Numéro de téléphone"), phone,
      el("button", { class: "mt", on: { click: request } }, "Recevoir le code"),
      codeBlock, status),
  );
}

logoutButton.addEventListener("click", () => {
  localStorage.removeItem("honam.refresh");
  access = null;
  showLogin();
});

// ── Tableau de bord ──────────────────────────────────────────────────────

async function showDashboard(tab = "") {
  logoutButton.hidden = false;
  let me, orders;
  try {
    me = await api("/honam/pharmacy/me");
    orders = await api(`/honam/pharmacy/orders${tab ? `?status=${tab}` : ""}`);
  } catch (e) {
    return render(el("h1", {}, "Espace officine"), errorBox(e.message));
  }
  const p = me.pharmacy;
  const banner = !me.visible ? el("div", { class: "card", role: "status" },
    el("span", { class: "pill danger" }, "Non visible des patients"),
    el("p", {}, p.status !== "ACTIVE" ? `Officine suspendue : ${p.suspension_reason || ""}` :
      !p.wallet_verified ? "Votre wallet n'est pas encore vérifié par l'équipe Pokou." :
      "Abonnement ou crédit à renouveler.")) : null;

  const duty = el("input", { type: "checkbox", id: "duty", checked: p.is_on_duty, class: "check" });
  duty.addEventListener("change", async () => {
    try { await api("/honam/pharmacy/on-duty", { method: "POST", body: { on_duty: duty.checked } }); }
    catch (e) { duty.checked = !duty.checked; alert(e.message); }
  });

  render(
    el("h1", {}, p.name),
    banner,
    el("div", { class: "card" },
      el("div", { class: "row" }, duty, el("label", { for: "duty", class: "m0" }, "Officine de garde")),
      el("p", { class: "muted" }, p.address, " · ", p.phone),
      el("div", { class: "stats" },
        stat("Reçues ce mois", me.stats_month.received), stat("Payées", me.stats_month.paid),
        stat("Livrées", me.stats_month.delivered), stat("Refusées", me.stats_month.rejected)),
    ),
    billing(me),
    el("h2", {}, "Commandes"),
    el("div", { class: "tabs", role: "group" }, TABS.map(([code, label]) =>
      el("button", { "aria-pressed": String(code === tab), on: { click: () => showDashboard(code) } }, label))),
    orders.items.length === 0 ? el("p", { class: "muted" }, "Aucune commande ici pour l'instant.") :
      orders.items.map((o) => el("div", { class: "card clickable", role: "button", tabindex: "0",
        on: { click: () => showOrder(o.id), keydown: (e) => e.key === "Enter" && showOrder(o.id) } },
        el("div", { class: "row" }, el("strong", { class: "grow" }, `Commande n° ${o.id}`), pill(o.status)),
        el("div", { class: "muted" }, o.patient_name || "Patient", " · ", when(o.created_at)),
        o.patient_paid_declared_at && o.status === "ACCEPTED" ? el("span", { class: "pill warning" }, "Le patient dit avoir payé") : null,
      )),
  );
}

function stat(label, value) {
  return el("div", { class: "stat card" }, el("strong", {}, value), el("span", { class: "muted" }, label));
}

function billing(me) {
  const sub = me.subscription, credit = me.credit, rate = sub.vat_rate;
  const ttc = (ht) => Math.round(ht * (1 + rate));
  const pay = async (path, body) => {
    try {
      const payment = await api(path, { method: "POST", body });
      if (payment.payment_url) window.location.href = payment.payment_url;
    } catch (e) { alert(e.message); }
  };
  const amount = el("input", { type: "number", min: "1000", step: "1000", value: "5000", "aria-label": "Montant du crédit HT" });
  return el("div", { class: "card" },
    el("h2", { class: "mt0" }, "Abonnement et crédit"),
    el("p", {}, sub.until ? `Abonnement ${sub.plan === "EPE" ? "ÉPÉ" : "Wétri"} HONAM jusqu'au ${when(sub.until)}` : "Aucun abonnement actif"),
    el("div", { class: "row" },
      el("button", { on: { click: () => pay("/honam/pharmacy/subscribe", { plan: "WETRI" }) } },
        `Wétri (mois) : ${fcfa(sub.prices_ht.WETRI)} HT · ${fcfa(ttc(sub.prices_ht.WETRI))} TTC`),
      el("button", { on: { click: () => pay("/honam/pharmacy/subscribe", { plan: "EPE" }) } },
        `ÉPÉ (an) : ${fcfa(sub.prices_ht.EPE)} HT · ${fcfa(ttc(sub.prices_ht.EPE))} TTC`)),
    el("p", {}, "Crédit : ", el("span", { class: "amount" }, fcfa(credit.balance_ht)), ` HT, soit ${credit.orders_left} commandes payées (100 FCFA HT chacune).`),
    credit.orders_left <= 10 ? el("span", { class: "pill warning" }, "Crédit bientôt épuisé") : null,
    el("div", { class: "row mt8" }, el("div", { class: "grow" }, amount),
      el("button", { class: "primary", on: { click: () => pay("/honam/pharmacy/credit", { amount_ht: Number(amount.value) }) } }, "Acheter du crédit")),
    el("p", { class: "muted" }, "Prix hors taxes, TVA du pays en sus."),
  );
}

// ── Détail d'une commande ────────────────────────────────────────────────

async function showOrder(id) {
  let o;
  try { o = await api(`/honam/pharmacy/orders/${id}`); } catch (e) { return alert(e.message); }
  const status = el("div");
  const act = (path, body, confirmText) => async () => {
    if (confirmText && !confirm(confirmText)) return;
    status.replaceChildren();
    try { await api(`/honam/pharmacy/orders/${id}/${path}`, { method: "POST", body }); showOrder(id); }
    catch (e) { status.append(errorBox(e.message)); }
  };

  const image = el("img", { class: "prescription", alt: "Ordonnance du patient" });
  if (o.prescription_media_id) {
    api(`/media/${o.prescription_media_id}`, { raw: true })
      .then((r) => r.ok ? r.blob() : null)
      .then((b) => { if (b) image.src = URL.createObjectURL(b); });
  }

  const sections = [];
  if (o.status === "SUBMITTED" || o.status === "QUOTED") sections.push(quoteEditor(o, status));
  if (o.status === "SUBMITTED") {
    const reason = el("input", { id: "reason", placeholder: "Ex. ordonnance illisible, périmée…" });
    sections.push(el("div", { class: "card" }, el("h2", { class: "mt0" }, "Refuser l'ordonnance"),
      el("label", { for: "reason" }, "Motif communiqué au patient"), reason,
      el("button", { class: "danger mt", on: { click: () => act("reject", { reason: reason.value })() } }, "Refuser")));
  }
  if (o.status === "ACCEPTED") {
    sections.push(el("div", { class: "card" },
      el("h2", { class: "mt0" }, "Paiement du patient"),
      el("p", {}, `À recevoir sur votre wallet : `, el("span", { class: "amount" }, fcfa(o.total))),
      o.patient_paid_declared_at ? el("p", {}, el("span", { class: "pill warning" }, `Le patient dit avoir payé (${when(o.patient_paid_declared_at)})`)) : null,
      el("div", { class: "row" },
        el("button", { class: "primary", on: { click: act("confirm-payment", null, "Confirmez-vous avoir reçu le paiement sur votre wallet ?") } }, "Paiement reçu"),
        el("button", { on: { click: act("payment-not-received") } }, "Paiement non reçu"))));
  }
  if (o.status === "PAID" && (o.missing_amount == null || o.missing_choice === "KEEP")) {
    sections.push(el("button", { class: "primary", on: { click: act("ready") } }, "Commande prête pour le coursier"));
  }
  // Le manque se signale pendant la préparation, avant tout coursier
  // (maquette A1) ; la patiente choisit ensuite (A2, A3).
  if (o.status === "PAID" && o.missing_amount == null) {
    const amount = el("input", { type: "number", min: "1", id: "missing" });
    const why = el("input", { id: "why", placeholder: "Produit en rupture…" });
    sections.push(el("div", { class: "card" }, el("h2", { class: "mt0" }, "Produit manquant"),
      el("p", { class: "muted" }, "À signaler avant d'appeler un coursier. La patiente choisira de recevoir le reste ou de tout annuler."),
      el("label", { for: "missing" }, "Montant des produits manquants (FCFA)"), amount,
      el("label", { for: "why" }, "Motif"), why,
      el("button", { class: "mt", on: { click: () => act("missing-product", { amount: Number(amount.value), reason: why.value })() } }, "Signaler le manque")));
  }
  if (o.missing_amount != null) {
    sections.push(el("div", { class: "card" }, el("h2", { class: "mt0" }, "Produit manquant"),
      el("p", {}, `Manquant : ${fcfa(o.missing_amount)} — ${o.missing_reason || ""}`),
      o.missing_choice == null ? el("span", { class: "pill warning" }, "En attente du choix de la patiente") :
        el("span", { class: "pill info" }, o.missing_choice === "KEEP" ? "La patiente reçoit le reste" : "Commande annulée par la patiente")));
  }
  if (o.refund_due > 0) {
    sections.push(el("div", { class: "card" }, el("h2", { class: "mt0" }, "Remboursement"),
      el("p", {}, "À rembourser : ", el("span", { class: "amount" }, fcfa(o.refund_due))),
      el("p", {}, "Uniquement sur le numéro qui a payé : ", el("strong", {}, o.refund_to_phone || "")),
      o.refund_confirmed_at ? el("span", { class: "pill success" }, "Reçu par la patiente") :
        el("span", { class: "pill danger" }, "Sous 2 h, sinon l'officine est suspendue")));
  }
  if (o.courier_name && ["READY", "IN_DELIVERY"].includes(o.status)) {
    sections.push(el("button", { on: { click: () => {
      const reason = prompt("Que s'est-il passé ? (coursier absent, colis non livré…)");
      if (reason) act("courier-default", { reason })();
    } } }, "Signaler un défaut du coursier"));
  }

  render(
    el("button", { class: "text", on: { click: () => showDashboard() } }, "← Commandes"),
    el("h1", {}, `Commande n° ${o.id}`),
    el("div", { class: "card" },
      el("div", { class: "row" }, el("strong", { class: "grow" }, o.patient_name || "Patient"), pill(o.status)),
      el("p", { class: "muted" }, "Livraison : ", o.delivery_address),
      o.patient_note ? el("p", {}, "Note du patient : ", o.patient_note) : null,
      o.courier_name ? el("p", {}, "Coursier : ", o.courier_name) : null,
      o.status === "DELIVERED" ? el("p", {}, o.courier_paid_at ? el("span", { class: "pill success" }, "Course payée au coursier") :
        el("span", { class: "pill warning" }, `Payez ${fcfa(o.delivery_price)} au coursier depuis votre wallet`)) : null,
      image),
    status,
    sections,
    el("h2", {}, "Suivi"),
    el("div", { class: "card" }, (o.timeline || []).map((e) => el("div", {}, pill(e.status), " ", el("span", { class: "muted" }, when(e.at)), e.note ? ` — ${e.note}` : ""))),
  );
}

function quoteEditor(o, status) {
  const rows = el("tbody");
  const addRow = (item = { name: "", quantity: 1, unit_price: "", available: true }) => {
    const name = el("input", { value: item.name, "aria-label": "Médicament" });
    const qty = el("input", { type: "number", min: "1", value: item.quantity, "aria-label": "Quantité", class: "w70" });
    const price = el("input", { type: "number", min: "0", value: item.unit_price, "aria-label": "Prix unitaire", class: "w110" });
    const available = el("input", { type: "checkbox", checked: item.available, "aria-label": "Disponible", class: "check" });
    const tr = el("tr", {}, el("td", {}, name), el("td", {}, qty), el("td", {}, price), el("td", {}, available),
      el("td", {}, el("button", { class: "text", "aria-label": "Retirer", on: { click: () => tr.remove() } }, "✕")));
    tr.read = () => ({ name: name.value.trim(), quantity: Number(qty.value), unit_price: Number(price.value), available: available.checked });
    rows.append(tr);
  };
  (o.quote_items && o.quote_items.length ? o.quote_items : [undefined]).forEach((i) => addRow(i));
  const original = el("input", { type: "checkbox", id: "orig", checked: o.original_required, class: "check" });
  const send = async () => {
    status.replaceChildren();
    const items = [...rows.children].map((tr) => tr.read()).filter((i) => i.name);
    try {
      await api(`/honam/pharmacy/orders/${o.id}/quote`, { method: "POST", body: { items, original_required: original.checked } });
      showOrder(o.id);
    } catch (e) { status.append(errorBox(e.message)); }
  };
  return el("div", { class: "card" },
    el("h2", { class: "mt0" }, o.status === "QUOTED" ? "Modifier le devis" : "Établir le devis"),
    el("table", {}, el("thead", {}, el("tr", {}, ["Médicament", "Qté", "Prix unit.", "Dispo", ""].map((h) => el("th", {}, h)))), rows),
    el("button", { class: "text", on: { click: () => addRow() } }, "+ Ajouter une ligne"),
    el("div", { class: "row mt8" }, original,
      el("label", { for: "orig", class: "m0" }, "Le coursier doit rapporter l'ordonnance originale")),
    el("p", { class: "muted" }, "Le prix de la course est ajouté par Honam selon le pays ; vous le reverserez au coursier après la livraison."),
    el("button", { class: "primary", on: { click: send } }, "Envoyer le devis"),
  );
}

// ── Démarrage ────────────────────────────────────────────────────────────

if ("serviceWorker" in navigator) navigator.serviceWorker.register("/officine/sw.js", { scope: "/officine/" });
refresh().then((ok) => ok ? showDashboard() : showLogin());
