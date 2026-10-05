---
description: Actualizar el catálogo DocTest y sus derivados cuando algo cambió en el sistema
argument-hint: [qué cambió — una pantalla, un bug corregido, un PR, un módulo]
---

# Actualizar DocTest

El PM (o un developer) avisa que algo cambió en el sistema y hay que reflejarlo en el catálogo
funcional y en todo lo que se deriva de él: los tests, los `.feature` y las ayudas de usuario.

**Qué cambió:** $ARGUMENTS

---

## Antes de tocar nada

1. Leé `doctest/GUIA-PRUEBAS-Y-AYUDAS.md` — cómo está organizado todo y dónde va cada cosa.
2. Leé `doc/v3/STATE.md` — en qué está el proyecto.
3. **Relevá contra lo que está desplegado, no contra tu rama.** Lo que corre en el DEMO es
   `develop`. Desde la sincronización del 2026-08-31 (PR #495) las dos ramas arrancan con el mismo
   contenido, pero vuelven a diverger: verificá igual que el commit del submódulo que estás leyendo
   coincida con el que apunta `origin/develop` del repo padre. La guía §1.4 tiene los comandos para
   leer la otra rama sin cambiar de rama.
   Y acordate de los repos que no son submódulos —`traz-comp-dnato` y `traz-prod-assetplanner` son
   repos aparte, con sus propias ramas—: ahí el relevamiento va contra su `origin/develop`.
4. Trabajá en una rama propia (`feature/...`), nunca sobre `develop-v3`.

## Identificá qué casos toca el cambio

Buscá en `doctest/catalogo/` por módulo, por pantalla o por el archivo de código que cambió — cada
caso declara sus `referencias_codigo`. Un cambio puede:

- **tocar un caso que ya existe** → se actualiza y, si el caso ya estaba `validado` y cambia su
  comportamiento, **se bumpea `version`** (regla R6, el CI la verifica);
- **necesitar un caso nuevo** → se agrega con el próximo id libre del módulo;
- **dejar un caso sin sentido** → pasa a `obsoleto` y se borran sus derivados en el mismo PR.

## Las tres formas del cambio

### a) Funcionalidad nueva o modificada

Relevá el código y la pantalla real. **Si hay una duda de intención de negocio, el caso va o queda en
`borrador` con la duda escrita** — nunca inventes para qué sirve algo. Un caso en borrador no genera
ningún derivado, y eso es deliberado.

Si la duda es puntual y el resto del caso está claro, escribí igual todo lo que sí sabés: el PM
responde una línea y el caso sale de borrador.

### b) Un bug corregido

Buscá el caso que lo describe. Los casos describen el comportamiento **esperado**, así que el caso ya
dice lo correcto: lo que hay que hacer es **sacar el `test.fail()` del spec** y verificar que ahora
pasa de verdad contra el entorno. Si pasa, el issue se cierra en ese PR.

Si el arreglo cambió además el comportamiento respecto de lo que el caso decía, ahí sí se actualiza
el caso y se bumpea la versión.

### c) Un hallazgo o un feedback

Los issues con label `test-gap` y `ayuda-gap` son entrada de trabajo: se convierten en casos nuevos o
en correcciones, y el PR que los incorpora los cierra con `Closes #N`.

## Regenerá lo derivado y verificá

Desde `doctest/`:

```bash
npm run validate:catalog     # schema + reglas duras
npm run features             # .feature desde los casos validados
npm run ayudas               # el sitio de ayudas, que sale en ayuda/ del repo
npm run typecheck
npm run test:module -- <modulo>   # o test:smoke si el cambio es transversal
```

Nada derivado se edita a mano de forma divergente: se corrige el caso y se regenera.

**Si tocaste una ayuda**, respetá la vara con que están escritas: son para alguien que se registró
solo y no tiene soporte. Pantallas dibujadas con las clases `screen-*`, secuencia de carga cuando el
formulario habilita campos en cadena, y los mensajes de error anticipados. Está en la guía.

## Al cerrar

1. Anotá en `doc/hallazgos/REGISTRO.md` lo que hayas encontrado de paso y no corresponda arreglar acá.
2. Actualizá `doc/v3/STATE.md`.
3. Abrí el PR con el formato de la metodología: qué cambia / por qué / cómo lo verificaste, con los
   comandos y sus resultados reales.

## Cuándo parar y preguntar

- Duda de **intención de negocio** → el caso queda en `borrador` con la duda. No la resuelvas vos.
- Duda **funcional con impacto en el usuario o en el modelo comercial** → pará y preguntá con
  opciones y una recomendación.
- Algo que **contradice o no cubre** el CONTEXT-PACK ni el documento canónico → pará y marcalo como
  "requiere decisión de arquitectura".
