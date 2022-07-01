<div class="container">
    <div class="box box-primary">
        <div class="box-header with-border">
            <h4 class="box-title">Test NOTIFICACIONES</h4>
        </div>
        <div class="box-body">
            <div class="row">
                <div class="col-md-12">
                    <form id="formNotificacion">
                        <div class="form-group">
                            <label for="formGroupExampleInput">Device Type</label>
                            <select class="form-control" id="dispositivo" name="dispositivo" required="">
                                <option value="">Select Device type</option>
                                <option value="android">Android</option>
                                <option value="iphone">IOS</option>
                        </select>
                        </div>           
                        <div class="form-group">
                            <label for="formGroupExampleInput">Notification Id</label>
                            <input type="text" name="noti_id" class="form-control" id="formGroupExampleInput" placeholder="Please enter notification id" readonly>
                        </div> 
                        <div class="form-group">
                            <button type="button" id="send_form" class="btn btn-success" onclick="haceAlgo()">Enviar!</button>
                        </div>
                    </form>
                </div>
            </div>
            <!-- FIN .row -->
        </div>
        <!-- FIN .box-body -->
    </div>
    <!-- FIN .box box-primary -->
</div>
<!-- FIN .container -->
<!-- <script type="module">
  // Import the functions you need from the SDKs you need
  import { initializeApp } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-app.js";
  import { getAnalytics } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-analytics.js";
  import { getMessaging } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-messaging.js";
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
  const analytics = getAnalytics(firebase);
  const pushNotifications = firebase.messaging();
  console.log(pushNotifications);
  console.log(firebase);
  firebase.messaging().requestPermission().then(function(token) {
        console.log('Recibido permiso.');
        }).catch(function(err) {
        error('No se ha obtenido permiso', err);
    });
</script> -->
<script type="module">
    import { firebase, analytics, messaging, sendPushNotification } from "./lib/props/firebase_config.js";
    window.sendPushNotification = () => {
        sendPushNotification();
    } 
    console.log(window.sendPushNotification());
// sendPushNotification();
</script>
<script>
    function haceAlgo(){
        var dataForm = new FormData($('#formNotificacion')[0]);
        $.ajax({
            type: 'POST',
            data: dataForm,
            cache: false,
            contentType: false,
            processData: false,
            // dataType: "json",
            url: "traz-comp-notificaciones/notificacion/haceAlgo",
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
    }

</script>