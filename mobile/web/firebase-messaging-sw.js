importScripts(
  'https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyAW-SFzZ4XTJy0y7n1gZwmU2_rNqqsOiNY',
  authDomain: 'pokou-3b047.firebaseapp.com',
  projectId: 'pokou-3b047',
  storageBucket: 'pokou-3b047.firebasestorage.app',
  messagingSenderId: '933534347521',
  appId: '1:933534347521:web:bc2973345f3004f082ab00',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(async (payload) => {
  const data = payload.data || {};
  const isCall = data.type === 'call';
  const title =
    payload.notification?.title ||
    (isCall ? data.caller_name : undefined);
  if (!title) return;

  const body =
    payload.notification?.body ||
    (isCall
      ? data.is_video === '1'
        ? 'Appel vidéo entrant'
        : 'Appel audio entrant'
      : '');

  await self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    tag: isCall ? `pokou-call-${data.room || 'incoming'}` : undefined,
    data: { link: self.location.origin, ...data },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = event.notification.data?.link || self.location.origin;
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(
      (clients) => {
        for (const client of clients) {
          if ('focus' in client) {
            client.navigate(link);
            return client.focus();
          }
        }
        return self.clients.openWindow(link);
      },
    ),
  );
});
