// client/web/firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// Initialize Firebase configuration natively for the web browser context
firebase.initializeApp({
  apiKey: "AIzaSyBUy-D-5hh5u7G6ecgzr333R4wdhlK-Lxk",
  authDomain: "echoground-9f92d.firebaseapp.com",
  projectId: "echoground-9f92d",
  storageBucket: "echoground-9f92d.firebasestorage.app",
  messagingSenderId: "600189671041",
  appId: "1:600189671041:web:5cacabe5a91205faaa5f80"
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
