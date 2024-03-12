
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
    apiKey: "AIzaSyCa5APkAQ9JPYVcQhc98jxb3wCn1031pMw",
    authDomain: "traz-prod-assetplanner.firebaseapp.com",
    projectId: "traz-prod-assetplanner",
    storageBucket: "traz-prod-assetplanner.appspot.com",
    messagingSenderId: "691647622823",
    appId: "1:691647622823:web:236fe74b3c824c522e3582",
    measurementId: "G-SCQ1GVP44M"
};

// Initialize Firebase
const firebase = initializeApp(firebaseConfig);
const auth = getAuth();
const analytics = getAnalytics(firebase);
const messaging = getMessaging(firebase);
console.log(messaging);
console.log(firebase);
console.log("HOLAaa");
// CLAVE PRIVADA CERTIFICADO PUSH WEB
// VEKOdGyFMACPAb2m_zOcpb0ZAl8xpos5LwmuI-6nhe8
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
      navigator.serviceWorker.register('/firebase-messaging-sw.js').then(function(registration) {
        // Registration was successful
        console.log('ServiceWorker registration successful with scope: ', registration.scope);
      }, function(err) {
        // registration failed :(
        console.log('ServiceWorker registration failed: ', err);
      });
    });
  }
function sendPushNotification(){
    Notification.requestPermission().then(function(permission) {
        if (permission === 'granted') {
            // sw.showNotification('ESOOO TILIN');
            console.log('Recibido permiso.');
            // En el parámetro "token" tienes el código para poder enviar las notificaciones
            getToken(messaging, { vapidKey: 'BLysBFbsObmUYACjOXtSS5BHNBwSjRFVW7hyN27xXpey8_hBO5XyiAN6iER0UbKXDs0J4VUy0RvtzDQTr-ptLQE' }).then((currentToken) => {
                if (currentToken) {
                    console.log("Tengo el tokenn");
                    // $("#noti_id").val(currentToken);
                    // var authToken = getAccessToken();
                    // var dataForm = new FormData($('#formNotificacion')[0]);
                    var jsonTest =  {
                        "registrationToken": currentToken,
                        "dataFieldsOfMessage":"key1:value1,key2:value2",
                        "notificationTitle":"test title",
                        "notificationBody":"test body",
                        "androidPriority":"normal",
                        "timeToLiveDuration":"123",
                        "restrictedPackageName":"com.google.firebase.quickstart.fcm",
                        "collapseKey":"test-key",
                        "dataFieldsOfAndroidConfig":"key3:value3,key4:value4",
                        "androidNotificationTitle":"Android Notification title",
                        "androidNotificationBody":"Android Notification body",
                        "androidClickAction":"android.intent.action.SHOW_APP_INFO",
                        "androidIcon":"@mipmap/ic_launcher",
                        "androidColor":"#112233",
                        "androidTag":"test-tag",
                        "androidSound":"@raw/bryan_sample",
                        "androidTitleLocalizationKey":"notification_title_string",
                        "androidBodyLocalizationKey":"notification_message_string",
                        "androidTitleLocalizationArgs":"t-arg2,t-arg3",
                        "androidBodyLocalizationArgs":"b-arg2,b-arg3",
                        "apnsHeaders":"header1:value1,header2:value2",
                        "apnsCustomData":"key5:value5,key6:value6",
                        "apnsBadge":"42",
                        "apnsSound":"apnsSound",
                        "apnsContentAvailable":true,
                        "apnsCategory":"category",
                        "apnsThreadId":"Thread-Id",
                        "apnsAlertTitle":"alert-title",
                        "apnsAlertBody":"alert-body",
                        "webPushHeaders":"header3:value3,header4:value4",
                        "webPushData":"key7:value7,key8:value8",
                        "webPushNotificationTitle":"web-notification-title",
                        "webPushNotificationBody":"web-notification-body",
                        "webPushNotificationIcon":"https://img.icons8.com/color/2x/baby-app.png",
                        "webPushNotificationBadge":"https://img.icons8.com/color/2x/ipad.png",
                        "webPushNotificationImage":"https://img.icons8.com/color/2x/ios-photos.png",
                        "webPushNotificationLanguage":"TA",
                        "webPushNotificationTag":"web-Tag",
                        "webPushNotificationDirection":"auto",
                        "webPushNotificationRenotify":true,
                        "webPushNotificationInteraction":false,
                        "webPushNotificationSilent":false,
                        "webPushNotificationTimestamp":"100",
                        "webPushNotificationVibrate":"200,100,200"
                    }
                    $.ajax({
                        type: 'POST',
                        data: jsonTest,
                        // cache: false,
                        // contentType: false,
                        // processData: false,
                        // dataType: "json",
                        // url: "traz-comp-notificaciones/notificacion/sendPushNotification",
                        url: "http://localhost:8290/tools/firebase/send",
                        success: function(data) { 
                            console.log(data);
                            // var rsp = JSON.parse(data);
                            // if(rsp.status){
                            //     console.log(data.message);
                            //     hecho("Notificación enviada correctamente");
                            // }else{
                            //     console.log(data.message);
                            //     error("Error enviando notificación");
                            // }
                            
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