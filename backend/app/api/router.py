"""Assemblage des routes de l'API.

`api_router` porte tout ce qui vit sous `/api/v1`. `public_router` porte les
adresses fixes que des tiers vont chercher sans préfixe : les fichiers
`/.well-known/` (vérification des App Links / Universal Links) et les pages
d'atterrissage des liens d'invitation, destinées à un navigateur.
"""
from fastapi import APIRouter

from app.api.public import deeplinks, legal, officine, suppression, wellknown
from app.api.v1.account import account_privacy, contacts, phone_change, profile
from app.api.v1.baba import baba
from app.api.v1.e2ee_retry import e2ee_retry
from app.api.v1.auth import auth, devices, e2ee
from app.api.v1.business import bot_api, business
from app.api.v1.calls import calls
from app.api.v1.certified import certified
from app.api.v1.config import country
from app.api.v1.communities import channels, communities
from app.api.v1.marketplace import assime, marketplace, marketplace_admin
from app.api.v1.media import media, stickers, status
from app.api.v1.honam import honam
from app.api.v1.kory import kory
from app.api.v1.messaging import broadcasts, conversations, groups, link_preview, messages, polls, presence, sync, ws
from app.api.v1.payments import webhooks as payment_webhooks
from app.api.v1.modules import heart_league, hype_train, modules, social_tax, streak_lock, truth_market, vip_room
from app.api.v1.safety import shield
from app.api.v1.spark import spark, spark_admin, spark_dates
from app.core import metrics

API_V1_PREFIX = "/api/v1"

api_router = APIRouter(prefix=API_V1_PREFIX)

for router in (
    # Même ordre que l'API d'origine : plusieurs routeurs sont sans préfixe,
    # et c'est l'ordre d'inclusion qui départage deux chemins concurrents.
    auth.router,
    ws.router,
    sync.router,
    contacts.router,
    messages.router,
    groups.router,
    communities.router,
    conversations.router,
    presence.router,
    polls.router,
    # Pokou Business : portail des entreprises et API des bots
    business.router,
    bot_api.router,
    account_privacy.router,
    profile.router,
    phone_change.router,
    baba.router,
    e2ee_retry.router,
    media.router,
    link_preview.router,
    status.router,
    channels.router,
    marketplace.router,
    marketplace_admin.router,
    assime.router,
    assime.admin_router,
    modules.router,
    modules.admin_router,
    heart_league.router,
    streak_lock.router,
    truth_market.router,
    social_tax.router,
    vip_room.router,
    hype_train.router,
    spark.router,
    spark_dates.router,
    spark_admin.router,
    calls.router,
    shield.router,
    devices.router,
    broadcasts.router,
    e2ee.router,
    stickers.router,
    payment_webhooks.router,
    country.router,
    kory.router,
    certified.router,
    certified.admin_router,
    honam.router,
    honam.admin_router,
    metrics.router,
):
    api_router.include_router(router)

public_router = APIRouter()
public_router.include_router(wellknown.router)
public_router.include_router(deeplinks.router)
public_router.include_router(officine.router)
public_router.include_router(suppression.router)
# Aussi sous /api/v1, pour que l'application les lise avec son client habituel.
public_router.include_router(legal.router)
api_router.include_router(legal.router)
