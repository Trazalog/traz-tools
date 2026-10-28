// Service worker del push web de Tools (ADR-015). Muestra los avisos cuando
// Tools no esta abierto en primer plano. Lo registra lib/props/firebase_config.js
// desde la raiz de Tools, asi que su alcance es toda la aplicacion.
importScripts("https://www.gstatic.com/firebasejs/9.8.4/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.8.4/firebase-messaging-compat.js");
importScripts("lib/props/firebase_web_config.js");

firebase.initializeApp(self.TZ_FIREBASE_CONFIG);
// Con el bloque "notification" del mensaje, Firebase muestra el aviso solo
// (titulo firmado por el agente si corresponde, e icono). Aca solo se maneja
// el clic: abrir Tools.
firebase.messaging();

self.addEventListener("notificationclick", (event) => {
    event.notification.close();
    const destino = self.registration.scope;
    event.waitUntil(
        clients.matchAll({ type: "window", includeUncontrolled: true }).then((ventanas) => {
            for (const v of ventanas) {
                if (v.url.indexOf(destino) === 0 && "focus" in v) { return v.focus(); }
            }
            return clients.openWindow(destino);
        })
    );
});
