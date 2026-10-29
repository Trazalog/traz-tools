// Configuracion WEB del proyecto Firebase (ADR-015). Es publica por diseno
// (la consola de Firebase la da para pegar en el navegador): no es la cuenta
// de servicio. Es un script comun y no un modulo para que lo puedan cargar
// tanto lib/props/firebase_config.js (import) como el service worker
// firebase-messaging-sw.js (importScripts).
self.TZ_FIREBASE_CONFIG = {
    apiKey: "AIzaSyCa5APkAQ9JPYVcQhc98jxb3wCn1031pMw",
    authDomain: "traz-prod-assetplanner.firebaseapp.com",
    projectId: "traz-prod-assetplanner",
    storageBucket: "traz-prod-assetplanner.appspot.com",
    messagingSenderId: "691647622823",
    appId: "1:691647622823:web:236fe74b3c824c522e3582",
    measurementId: "G-SCQ1GVP44M"
};

// Clave publica VAPID del push web (Firebase > Cloud Messaging > Web Push).
self.TZ_FIREBASE_VAPID = 'BLysBFbsObmUYACjOXtSS5BHNBwSjRFVW7hyN27xXpey8_hBO5XyiAN6iER0UbKXDs0J4VUy0RvtzDQTr-ptLQE';
