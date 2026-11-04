// Suppression de compte depuis le web (AUTH-06, exigée par Google Play et
// l'App Store). Trois étapes : le numéro, le code reçu par SMS, puis le
// numéro retapé pour confirmer.
//
// La page n'a aucun pouvoir propre : elle se connecte comme l'application,
// avec un code à usage unique, puis appelle la MÊME route de suppression.
// Sans le code, rien ne part — on ne supprime pas un compte sur la seule
// foi d'un numéro saisi par un inconnu.
"use strict";

const API = "/api/v1";
const $ = (id) => document.getElementById(id);
const message = $("message");

let token = null;

function dire(texte, ton) {
  message.replaceChildren();
  const boite = document.createElement("div");
  boite.className = "notice " + (ton || "info");
  boite.textContent = texte;
  message.append(boite);
}

async function appeler(chemin, options) {
  const reponse = await fetch(API + chemin, {
    method: (options && options.method) || "GET",
    headers: Object.assign(
      { "Content-Type": "application/json" },
      token ? { Authorization: "Bearer " + token } : {},
    ),
    body: options && options.body ? JSON.stringify(options.body) : undefined,
  });
  let corps = null;
  try { corps = await reponse.json(); } catch (_) { corps = null; }
  if (!reponse.ok) {
    const detail = corps && corps.detail;
    const texte = typeof detail === "string"
      ? detail
      : (detail && detail.message) || "L'opération n'a pas abouti.";
    throw new Error(texte);
  }
  return corps;
}

function occupe(bouton, actif) {
  bouton.disabled = actif;
}

$("envoyer").addEventListener("click", async () => {
  const phone = $("phone").value.trim();
  if (!phone) return dire("Indiquez votre numéro.", "error");
  occupe($("envoyer"), true);
  try {
    await appeler("/auth/phone/request-otp", { method: "POST", body: { phone } });
    $("etape-code").hidden = false;
    dire("Code envoyé. Il est valable peu de temps : saisissez-le tout de suite.", "info");
    $("code").focus();
  } catch (e) {
    dire(e.message, "error");
  } finally {
    occupe($("envoyer"), false);
  }
});

$("verifier").addEventListener("click", async () => {
  const phone = $("phone").value.trim();
  const code = $("code").value.trim();
  if (code.length !== 6) return dire("Le code compte 6 chiffres.", "error");
  occupe($("verifier"), true);
  try {
    const corps = await appeler("/auth/phone/verify-otp", {
      method: "POST",
      body: { phone, code },
    });
    if (!corps || !corps.access_token) {
      // Compte protégé par un code PIN : la vérification en deux étapes ne
      // se fait pas ici. On le DIT, au lieu d'échouer sans raison visible.
      dire(
        "Ce compte demande son code PIN. Ouvrez l'application Pokou pour "
          + "supprimer le compte (Plus → Confidentialité), ou écrivez au support.",
        "error",
      );
      return;
    }
    token = corps.access_token;
    $("etape-confirmation").hidden = false;
    dire("Numéro vérifié. Dernière étape.", "ok");
    $("confirm").focus();
  } catch (e) {
    dire(e.message, "error");
  } finally {
    occupe($("verifier"), false);
  }
});

$("supprimer").addEventListener("click", async () => {
  if (!token) return dire("Vérifiez d'abord votre numéro.", "error");
  const confirmPhone = $("confirm").value.trim();
  if (!confirmPhone) return dire("Retapez votre numéro pour confirmer.", "error");
  if (!window.confirm("Supprimer définitivement votre compte Pokou ? Cette action est irréversible.")) return;
  occupe($("supprimer"), true);
  try {
    await appeler("/account-privacy/account", {
      method: "DELETE",
      body: { confirm_phone: confirmPhone },
    });
    token = null;
    $("etape-numero").hidden = true;
    $("etape-code").hidden = true;
    $("etape-confirmation").hidden = true;
    dire(
      "Votre compte Pokou est supprimé. Votre numéro est de nouveau libre : "
        + "vous pouvez vous réinscrire quand vous voulez, sur un compte neuf.",
      "ok",
    );
  } catch (e) {
    dire(e.message, "error");
  } finally {
    occupe($("supprimer"), false);
  }
});
