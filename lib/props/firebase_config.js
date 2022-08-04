
// Funciones importadas del SDKs necesarias
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-app.js";
import { getAnalytics } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-analytics.js";
import { getMessaging, getToken } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-messaging.js";
import { getAuth, createUserWithEmailAndPassword }  from "https://www.gstatic.com/firebasejs/9.8.4/firebase-auth.js";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// PWA Firebase configuracion, se obtiene de la consola al crear la instancia del proyecto
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

// CLAVE PRIVADA CERTIFICADO PUSH WEB
// VEKOdGyFMACPAb2m_zOcpb0ZAl8xpos5LwmuI-6nhe8

function sendPushNotification(){
    Notification.requestPermission().then(function(permission) {
        if (permission === 'granted') {
            // sw.showNotification('ESOOO TILIN');
            console.log('Recibido permiso.');
            // En el parámetro "token" tienes el código para poder enviar las notificaciones
            getToken(messaging, { vapidKey: 'BBr_p7ZaAscFxO9ljqvTGnsf-_7L8NY7W_VOaWxHFcjjmmfeYYOTTeVogvzExptd0O0gpvGrIAVh9HQwbHiD6w8' }).then((currentToken) => {
                if (currentToken) {
                    $("#noti_id").val(currentToken);
                    // var authToken = getAccessToken();
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
                } else {
                    error("Error!","Se vencio el token de registro, solicita permiso para generar uno nuevo.");
                }
                }).catch((err) => {
                console.log('Se produjo un error al generar el TOKEN. ', err);
            });
        }else{
            console.log('Permiso rechazado.');
        }
        }).catch(function(err) {
            console.log(err);
        error('No se ha obtenido permiso', err);
    });
}
export {firebase, analytics, messaging, sendPushNotification};