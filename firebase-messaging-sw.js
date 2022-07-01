// Note that you can only use Firebase Messaging here. Other Firebase libraries
 // are not available in the service worker.
 importScripts('https://www.gstatic.com/firebasejs/9.2.0/firebase-app-compat.js');
 importScripts('https://www.gstatic.com/firebasejs/9.2.0/firebase-messaging-compat.js');
//  importScripts('https://www.gstatic.com/firebasejs/9.2.0/firebase-init.js');
 // Initialize the Firebase app in the service worker by passing in
 // your app's Firebase config object.
 // https://firebase.google.com/docs/web/setup#config-object
 // Import and configure the Firebase SDK
// These scripts are made available when the app is served or deployed on Firebase Hosting
// If you do not serve/host your project using Firebase Hosting see https://firebase.google.com/docs/web/setup
// importScripts('/__/firebase/9.2.0/firebase-app-compat.js');
// importScripts('/__/firebase/9.2.0/firebase-messaging-compat.js');
// importScripts('/__/firebase/init.js');

// const messaging = firebase.messaging();

/**
 * Here is is the code snippet to initialize Firebase Messaging in the Service
 * Worker when your app is not hosted on Firebase Hosting.
 // Give the service worker access to Firebase Messaging.
 // Note that you can only use Firebase Messaging here. Other Firebase libraries
 // are not available in the service worker.
 importScripts('https://www.gstatic.com/firebasejs/9.2.0/firebase-app-compat.js');
 importScripts('https://www.gstatic.com/firebasejs/9.2.0/firebase-messaging-compat.js');
 // Initialize the Firebase app in the service worker by passing in
 // your app's Firebase config object.
 // https://firebase.google.com/docs/web/setup#config-object
 */
 firebase.initializeApp({
    apiKey: "AIzaSyD-D8C5EuzKsYxAfIKJeps-IPT3RUEuQjU",
    authDomain: "baupedistribuidora-3eee5.firebaseapp.com",
    projectId: "baupedistribuidora-3eee5",
    storageBucket: "baupedistribuidora-3eee5.appspot.com",
    messagingSenderId: "586234869476",
    appId: "1:586234869476:web:5ea79c612570b62f0ddef1",
    measurementId: "G-MRFMZKTEGE"
});
 // Retrieve an instance of Firebase Messaging so that it can handle background
 // messages.
 const messaging = firebase.messaging();

 if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./firebase-messaging-sw.js")
    .then(function(registration) {
      console.log("Registration successful, scope is:", registration.scope);
      getToken({vapidKey: 'BBr_p7ZaAscFxO9ljqvTGnsf-_7L8NY7W_VOaWxHFcjjmmfeYYOTTeVogvzExptd0O0gpvGrIAVh9HQwbHiD6w8', serviceWorkerRegistration : registration })
        .then((currentToken) => {
          if (currentToken) {
            console.log('current token for client: ', currentToken);
  
            // Track the token -> client mapping, by sending to backend server
            // show on the UI that permission is secured
          } else {
            console.log('No registration token available. Request permission to generate one.');
  
            // shows on the UI that permission is required 
          }
        }).catch((err) => {
          console.log('An error occurred while retrieving token. ', err);
          // catch error while creating client token
        });  
      })
      .catch(function(err) {
        console.log("Service worker registration failed, error:"  , err );
    }); 
  }

// If you would like to customize notifications that are received in the
// background (Web app is closed or not in browser focus) then you should
// implement this optional method.
// Keep in mind that FCM will still show notification messages automatically 
// and you should use data messages for custom notifications.
// For more info see: 
// https://firebase.google.com/docs/cloud-messaging/concept-options
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = 'Background Message Title';
  const notificationOptions = {
    body: 'Background Message body.',
    icon: '/firebase-logo.png'
  };

  self.registration.showNotification(notificationTitle,
    notificationOptions);
});