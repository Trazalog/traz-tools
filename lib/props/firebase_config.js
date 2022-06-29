
// Import the functions you need from the SDKs you need
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-app.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-analytics.js";
import { getMessaging, getToken } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-messaging.js";
import { getAuth, createUserWithEmailAndPassword }  from "https://www.gstatic.com/firebasejs/9.8.4/firebase-auth.js";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
apiKey: "AIzaSyD-D8C5EuzKsYxAfIKJeps-IPT3RUEuQjU",
authDomain: "baupedistribuidora-3eee5.firebaseapp.com",
projectId: "baupedistribuidora-3eee5",
storageBucket: "baupedistribuidora-3eee5.appspot.com",
messagingSenderId: "586234869476",
appId: "1:586234869476:web:5ea79c612570b62f0ddef1",
measurementId: "G-MRFMZKTEGE"
};

// Initialize Firebase
const firebase = initializeApp(firebaseConfig);
const auth = getAuth();
const analytics = getAnalytics(firebase);
const messaging = getMessaging(firebase);
//   console.log(firebase);
//   console.log(messaging);
//   messaging.requestPermission().then(function(token) {
//         console.log('Recibido permiso.');
//         }).catch(function(err) {
//         error('No se ha obtenido permiso', err);
//     });
// const firebase = initializeApp(firebaseConfig);
// getToken({vapidKey: "BBr_p7ZaAscFxO9ljqvTGnsf-_7L8NY7W_VOaWxHFcjjmmfeYYOTTeVogvzExptd0O0gpvGrIAVh9HQwbHiD6w8"});
// if ("serviceWorker" in navigator) {
//     navigator.serviceWorker.register("./firebase-messaging-sw.js")
//       .then(function(registration) {
//         console.log("Registration successful, scope is:", registration.scope);
//         getToken({vapidKey: 'BBr_p7ZaAscFxO9ljqvTGnsf-_7L8NY7W_VOaWxHFcjjmmfeYYOTTeVogvzExptd0O0gpvGrIAVh9HQwbHiD6w8', serviceWorkerRegistration : registration })
//           .then((currentToken) => {
//             if (currentToken) {
//               console.log('current token for client: ', currentToken);
    
//               // Track the token -> client mapping, by sending to backend server
//               // show on the UI that permission is secured
//             } else {
//               console.log('No registration token available. Request permission to generate one.');
    
//               // shows on the UI that permission is required 
//             }
//           }).catch((err) => {
//             console.log('An error occurred while retrieving token. ', err);
//             // catch error while creating client token
//           });  
//         })
//         .catch(function(err) {
//           console.log("Service worker registration failed, error:"  , err );
//       }); 
//     }
console.log(auth);
console.log(firebase);
console.log(messaging);

function sendPushNotification(){
    // console.log(firebase);
    // console.log(messaging);
    Notification.requestPermission().then(function(permission) {
        if (permission === 'granted') {
            console.log('Notification permission granted.');
        }
            console.log('Recibido permiso.');
            // En el parámetro "token" tienes el código para poder enviar las notificaciones
            var dataForm = new FormData($('#formNotificacion')[0]);
            $.ajax({
                type: 'POST',
                data: dataForm,
                cache: false,
                contentType: false,
                processData: false,
                // dataType: "json",
                url: "traz-comp-notificaciones/notificacion/sendPushNotification",
                success: function(data) { 
                    var rsp = JSON.parse(data);
                    if(rsp.status){
                        console.log(data.message);
                        hecho("Notificación enviada correctamente");
                    }else{
                        console.log(data.message);
                        error("Error enviando notificación");
                    }
                    
                },
                error: function(data) {
                    error("Error enviando notificación");
                }
            });
        }).catch(function(err) {
            console.log(err);
        error('No se ha obtenido permiso', err);
    });
}
export {firebase, analytics, messaging, sendPushNotification};