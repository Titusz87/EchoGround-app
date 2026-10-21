// client/web/firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Initialize Firebase configuration natively for the web browser context
firebase.initializeApp({
  apiKey: "AIzaSyCEHGEaPKdVvy5ztmxJRQOeX08FOtBU1Hc",
  authDomain: "country-ready.firebaseapp.com",
  projectId: "country-ready",
  storageBucket: "country-ready.firebasestorage.app",
  messagingSenderId: "254583394013",
  appId: "1:254583394013:web:bc071bd0dc394a2b07d534"
});

const messaging = firebase.messaging();

// Process incoming background incident data packages when the web tab is closed
messaging.onBackgroundMessage((payload) => {
  console.log("Background incident payload received: ", payload);

  const notificationTitle = payload.data.title || "Incident Alert";
  const notificationOptions = {
    body: payload.data.body || "A local dataset has been updated.",
    icon: "/EchoGround-app/icons/Icon-192.png", 
    data: {
      url: payload.data.link || "/EchoGround-app/" 
    }
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Capture background box clicks and route/refocus the user device browser tab
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = event.notification.data.url;

  if (targetUrl) {
    event.waitUntil(
      clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
        for (let client of windowClients) {
          if (client.url === targetUrl && "focus" in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow(targetUrl);
        }
      })
    );
  }
});
