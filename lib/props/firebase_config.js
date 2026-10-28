// Push web de Tools (ADR-015): registra el navegador del usuario para recibir
// los avisos. El envio lo hace el transporte (Siddhi AvisosPush), nunca el
// navegador.
//
//   - Si el usuario ya habia dado permiso, se re-registra solo al cargar (el
//     token de Firebase puede cambiar).
//   - Si no, el permiso se pide recien cuando el usuario toca "Recibir avisos
//     en este navegador" en la campanita (TZAvisosPush.activar()): pedirlo
//     solo al entrar hace que el navegador lo bloquee.
//   - Al salir de Tools se da de baja el navegador (avisos.js).
//
// Antes este archivo armaba un push de prueba y lo mandaba al MI desde el
// navegador; nunca registraba el token.
import "./firebase_web_config.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-app.js";
import { getMessaging, getToken, onMessage, isSupported } from "https://www.gstatic.com/firebasejs/9.8.4/firebase-messaging.js";

const BASE = (window.TZ_BASE_URL || (location.origin + "/"));
const CLAVE_TOKEN = "tz_avisos_token";

function guardarToken(token) {
    try { localStorage.setItem(CLAVE_TOKEN, token); } catch (e) { /* modo privado */ }
}

async function registrarEnTools(token) {
    const datos = new URLSearchParams({ token: token });
    const rsp = await fetch(BASE + "index.php/Avisos/dispositivo", {
        method: "POST", body: datos, credentials: "same-origin",
        headers: { "Content-Type": "application/x-www-form-urlencoded" }
    });
    if (!rsp.ok) { throw new Error("Tools no registro el navegador (" + rsp.status + ")"); }
    guardarToken(token);
}

async function iniciar() {
    if (!("serviceWorker" in navigator) || !("Notification" in window) || !(await isSupported())) {
        window.TZAvisosPush = { soportado: false, activar: async () => false };
        return;
    }
    const app = initializeApp(self.TZ_FIREBASE_CONFIG);
    const messaging = getMessaging(app);
    // El service worker vive en la raiz de Tools (no del dominio): Tools puede
    // estar servido en una subcarpeta.
    const registro = await navigator.serviceWorker.register(BASE + "firebase-messaging-sw.js");

    async function obtenerYRegistrar() {
        const token = await getToken(messaging, {
            vapidKey: self.TZ_FIREBASE_VAPID, serviceWorkerRegistration: registro
        });
        if (!token) { return false; }
        await registrarEnTools(token);
        return true;
    }

    window.TZAvisosPush = {
        soportado: true,
        permiso: () => Notification.permission,
        activar: async () => {
            const permiso = await Notification.requestPermission();
            if (permiso !== "granted") { return false; }
            return obtenerYRegistrar();
        }
    };

    if (Notification.permission === "granted") {
        obtenerYRegistrar().catch((e) => console.warn("Avisos: no se pudo registrar el navegador", e));
    }

    // Con Tools abierto el push no lo muestra el service worker: se muestra
    // aca y se actualiza la campanita.
    onMessage(messaging, (payload) => {
        const n = payload.notification || {};
        if (Notification.permission === "granted") {
            registro.showNotification(n.title || "Trazalog", { body: n.body || "", icon: n.icon || n.image });
        }
        if (window.TZAvisos && window.TZAvisos.refrescar) { window.TZAvisos.refrescar(); }
    });
}

iniciar().catch((e) => console.warn("Avisos: push web no disponible", e));
