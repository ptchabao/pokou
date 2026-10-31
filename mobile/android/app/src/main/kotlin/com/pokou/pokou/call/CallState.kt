package com.pokou.pokou.call

/**
 * L'état d'un appel entrant, et les seules transitions permises.
 *
 * Une énumération à part, et non une chaîne de caractères : c'est le
 * compilateur qui doit refuser un état inventé, pas une comparaison de
 * texte au moment où le téléphone sonne.
 */
enum class CallState {
    /** Le push est arrivé, ça sonne. */
    RINGING,

    /** L'utilisateur a touché « Répondre » ; on prévient le serveur. */
    ANSWERING,

    /** Le serveur a pris acte ; Flutter rejoint le salon média. */
    CONNECTING,

    /** Le média est établi. */
    CONNECTED,

    /** Refusé, raccroché, ou terminé normalement. */
    ENDED,

    /** Personne n'a répondu avant la fin de la sonnerie. */
    MISSED,

    /** Le serveur a refusé, ou le réseau n'a pas répondu. */
    FAILED;

    /**
     * Un état où la sonnerie doit être ARRÊTÉE.
     *
     * Tout sauf `RINGING`, donc — la liste est écrite à l'envers exprès :
     * ajouter un état demain sans y penser fera taire la sonnerie plutôt
     * que de la laisser tourner indéfiniment. C'est le sens du défaut qu'on
     * veut, et il n'est pas symétrique.
     */
    val isSilent: Boolean get() = this != RINGING

    /** Un état terminal : plus rien n'en sort. */
    val isTerminal: Boolean get() = this == ENDED || this == MISSED || this == FAILED
}

/**
 * Un appel entrant, tel que le natif le connaît.
 *
 * `room` et non `callId` : c'est l'identifiant que porte la signalisation
 * côté serveur — `CallLog.room == room`. Le renommer ici obligerait à
 * traduire à chaque frontière, et c'est exactement là que les identifiants
 * se perdent.
 */
data class IncomingCall(
    val room: String,
    val fromUserId: String,
    val callerName: String,
    val isVideo: Boolean,
    val groupId: String?,
    val groupName: String?,
    /** Le laissez-passer pour accepter. Voir docs/native-call-layer.md §3. */
    val answerToken: String?,
    /** Le laissez-passer pour refuser. */
    val declineToken: String?,
) {
    companion object {
        const val KEY_ROOM = "room"
        const val KEY_FROM_USER_ID = "from_user_id"
        const val KEY_CALLER_NAME = "caller_name"
        const val KEY_IS_VIDEO = "is_video"
        const val KEY_GROUP_ID = "group_id"
        const val KEY_GROUP_NAME = "group_name"
        const val KEY_ANSWER_TOKEN = "answer_token"
        const val KEY_DECLINE_TOKEN = "decline_token"

        /**
         * Reconstruit l'appel depuis le payload FCM.
         *
         * Renvoie `null` si le salon manque : sans lui, rien n'est
         * actionnable — ni accepter, ni refuser, ni même dire au serveur que
         * l'appel a été manqué. Mieux vaut ignorer le push que d'afficher
         * une notification dont aucun bouton ne marche.
         */
        fun fromData(data: Map<String, String>): IncomingCall? {
            val room = data[KEY_ROOM]?.takeIf { it.isNotBlank() } ?: return null
            return IncomingCall(
                room = room,
                fromUserId = data[KEY_FROM_USER_ID].orEmpty(),
                callerName = data[KEY_CALLER_NAME]?.takeIf { it.isNotBlank() } ?: "Pokou",
                isVideo = data[KEY_IS_VIDEO] == "1",
                groupId = data[KEY_GROUP_ID],
                groupName = data[KEY_GROUP_NAME],
                answerToken = data[KEY_ANSWER_TOKEN],
                declineToken = data[KEY_DECLINE_TOKEN],
            )
        }
    }
}
