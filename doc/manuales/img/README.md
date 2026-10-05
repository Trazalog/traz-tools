# Capturas del manual

Imágenes que acompañan a [`conectar-claude-a-trazalog.md`](../conectar-claude-a-trazalog.md).
Guardar con estos nombres exactos — el manual las referencia así.

| Archivo | Qué muestra |
|---|---|
| `01-menu-conectores.png` | Pantalla **Conectores** de la configuración de Claude (la lista de conectores, con "Conectores" seleccionado en el menú lateral) |
| `02-agregar-conector.png` | El menú **Agregar** desplegado, mostrando la opción *Agregar conector personalizado* |
| `03-formulario.png` | El diálogo **Agregar conector personalizado** con el nombre (`Trazalog`) y la URL cargados |
| `04-login-trazalog.png` | La pantalla de acceso de Trazalog: *"Claude solicita acceder a Trazalog. Ingrese sus credenciales para continuar"* |
| `05-conectado.png` | La confirmación **Conectado** que aparece al terminar |

> **No hay pantalla de autorización separada.** En Trazalog el consentimiento y el login están
> unificados en `04`: el mismo formulario avisa que Claude solicita acceso y pide las
> credenciales. Una versión anterior del manual asumía dos pantallas distintas.

---

## Antes de guardar las capturas

Este manual **se comparte con clientes**. Revisar en cada imagen:

- [ ] **Usuario/email visible** — la captura de login muestra el email de quien probó
      (ej. `jperez@metalmecanica.com`). Reemplazar por uno genérico tipo `usuario@empresa.com`,
      o difuminarlo.
- [ ] **Nombre de la empresa** y cualquier dato de negocio.
- [ ] **Otros conectores personales** en la lista (Gmail, Drive, GitHub…) — si son cuentas
      reales, conviene recortar la captura a la zona relevante.
- [ ] **El logo de Trazalog no carga** en la pantalla de login (se ve el ícono de imagen rota).
      Es un defecto conocido de ese ambiente: `Oauthlogin::_getLogo()` lee el logo de la tabla
      `configuraciones_ui` y devuelve vacío si no lo encuentra. Conviene arreglarlo antes de
      sacar la captura definitiva, o la imagen queda con el logo roto en un doc de cara al
      cliente. Ver `doc/v3/deployment-gcp.md` §7.0-quinquies.

## Formato

- PNG, ancho ~1000-1200 px (legible sin ser pesado).
- Recortar a la zona relevante: no hace falta la pantalla completa.
