# ADR-015 — Marca por dominio (Pirkai)

## Objetivo

Registra cómo el sistema decide qué marca mostrar (Trazalog o Pirkai) según el dominio por el que entra
el usuario, y qué reglas siguen las pantallas y las direcciones entre aplicaciones. Para quien toque la
plantilla de Tools, el ingreso (DNATO) o agregue una marca. **No** cubre los pasos de servidor y dominio
(están en `doc/infra/pirkai-0*.md`) ni el detalle del trabajo ([REQ-019](../../requerimientos/REQ-019-marca-por-dominio.md)).

- **Estado:** Propuesto (2026-11-26). La decisión de fondo (un segundo dominio con marca propia, mismo
  sistema) es de Rodolfo; las reglas técnicas las propone Claude Code y quedan para su aprobación junto
  con el pedido de cambio de REQ-019
- **Relacionado:** ADR-009 (identidad del agente, emisor del token), ADR-011 (despliegue en GCP)

---

## Contexto

Rodolfo pidió que el sistema se pueda usar desde `app.pirkai.net` mostrando la marca Pirkai, sin cambiar
nada para quien entra por el dominio de Trazalog. El relevamiento (2026-11-26) mostró:

- No había ningún mecanismo de temas ni lógica por dominio.
- La marca de Tools sale de una sola plantilla (`layout/Admin.php`) más datos globales de `core.tablas`
  (`configuraciones_uitoolsLogoNavbar`, sin empresa).
- Tools y DNATO comparten la sesión porque corren en el mismo servidor y dominio. DNATO devuelve al
  usuario a direcciones absolutas fijas (`DE`, `DS`), y Tools lo manda a DNATO con otra (`DNATO`).
- Esos valores viven en `constants.php`, que se edita a mano en cada servidor y que el despliegue
  respalda y restaura.
- El emisor (`iss`) de los tokens del agente se deriva de `base_url` si no está configurado.

## Decisión

1. **La marca se resuelve por el dominio del pedido contra una lista cerrada**, en un archivo versionado
   (`application/config/marcas.php`), no en la base. Motivos: el ingreso no tiene sesión ni empresa, se
   resuelve en cada pedido sin llamar a WSO2, y no agrega recursos de WSO2 ni filas de base. Un dominio
   que no está en la lista muestra Trazalog; nunca se usa el dominio crudo del pedido.
2. **La marca por defecto (Trazalog) no se define en el archivo.** Sus valores siguen saliendo de donde
   salen hoy (`core.tablas`, constantes, vistas). Toda pantalla llama a `marca('clave', '<valor de hoy>')`:
   con Trazalog el resultado es exactamente el de antes.
3. **Una función global como contrato**, `marca()` (helper autocargado, igual en Tools y DNATO), y
   `window.MARCA` en el navegador. Los módulos con repositorio propio la usan con
   `function_exists('marca')`, para seguir andando contra un Tools anterior.
4. **Las direcciones entre aplicaciones siguen al dominio del pedido** solo si es de otra marca
   (`marca_url_host()`); con Trazalog quedan intactas. El ingreso de una marca se sirve en su mismo
   dominio, así la sesión compartida sigue funcionando. Las sesiones quedan separadas por dominio.
5. **El emisor de tokens del agente no depende del dominio.** Se configura explícito en cada servidor
   (`DNATO_OAUTH_ISSUER`) y, si falta, con otra marca se deriva de la constante fija `DNATO`, nunca del
   dominio del pedido.
6. **Colores en dos etapas.** Primero una hoja `marca.css` que se carga solo con la marca y pisa el skin
   y los acentos más repetidos; después, variables CSS (`--marca-primario`) y limpieza por módulo. El rojo
   de "peligro" y de "campo obligatorio" no es marca y no se cambia.

## Consecuencias

- Sumar un dominio o una marca es editar un archivo y desplegar; no toca base ni WSO2.
- Cada servidor necesita un ajuste manual en `constants.php` de Tools (envolver `DNATO`), porque el
  despliegue restaura ese archivo. Si falta, el sistema funciona pero el ingreso se ve con Trazalog.
- El archivo de marcas y el helper están duplicados en dos repositorios; se cambian juntos.
- Quedan con Trazalog, hasta la Etapa B, las páginas sueltas de módulos con repositorio propio y algunos
  colores puntuales (lista en REQ-019).

## Alternativas descartadas

- **Filas por marca en `core.tablas`**: obliga a resolver el dominio antes de tener sesión y a consultar
  WSO2 en cada pedido; queda como opción si algún día se quiere editar la marca sin desplegar.
- **Instalación separada por marca**: duplica servidores, despliegues y configuración para cambiar solo
  la apariencia.
- **Reemplazar los textos en cada módulo de una vez**: 8 repositorios y decenas de archivos antes de poder
  mostrar nada; se hace de a poco en la Etapa B.
