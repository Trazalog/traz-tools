# Cómo reportar lo que falta — proceso de feedback

## Objetivo

Explica cómo reportás algo que falta o está mal, y qué pasa después con lo que reportaste. Está
escrito para **testers y usuarios del sistema**, sin dar por sentado que usás git ni que sabés
programar. **No** cubre cómo se escriben los casos ni cómo se corren las pruebas: eso está en
[`../GUIA-PRUEBAS-Y-AYUDAS.md`](../GUIA-PRUEBAS-Y-AYUDAS.md).

---

## Los tres canales

Todo entra por **GitHub Issues** del repo `Trazalog/traz-tools`. **Dónde:** en el navegador, en
<https://github.com/Trazalog/traz-tools/issues/new/choose>. Ahí elegís la plantilla:

| Lo que encontraste | Plantilla | Ejemplo |
|---|---|---|
| Un flujo que el sistema hace y **las pruebas no cubren** | **Falta probar algo (test-gap)** | "Nadie prueba qué pasa si doy de alta un equipo sin componentes" |
| La **ayuda de usuario** dice algo que no es, falta o se entiende mal | **La ayuda está mal o falta (ayuda-gap)** | "La ayuda dice que el enlace vale 24 h y vale hasta la medianoche" |
| El sistema **hace algo distinto de lo que dice hacer** | Issue en blanco, con label `bug` | "Cambié la contraseña y sigue entrando con la vieja" |

La diferencia entre el primero y el tercero: **test-gap** es "esto nadie lo está mirando";
**bug** es "esto está roto". Si dudás, abrilo igual — se reetiqueta en un minuto y es mucho peor
que se pierda.

> **Si no tenés cuenta de GitHub**, mandáselo a Rodolfo por el canal que uses siempre y él lo
> transcribe. No dejes de reportarlo por eso.

---

## Qué escribir

Lo único que se pide siempre es esto:

1. **Qué hiciste**, en pasos, como si se lo contaras a alguien que va a repetirlo.
2. **Qué esperabas** que pasara.
3. **Qué pasó** en cambio.

No hace falta que propongas la solución ni que sepas por qué pasa. Si tenés una captura, adjuntala
arrastrándola al cuadro de texto.

---

## Qué pasa después

```
tu issue ──> el PM lo tría ──> se agrega o corrige el caso en el catálogo ──> se regeneran
                                                                              tests, .feature
                                                                              y ayudas
                                                                                    │
                          el PR que hace eso cierra tu issue con "Closes #N" <──────┘
```

Concretamente:

- Un **test-gap** termina como un caso de uso nuevo o corregido en `doctest/catalogo/`, del que
  salen el test automatizado y el `.feature` que vas a leer la próxima vez.
- Un **ayuda-gap** termina como una corrección en el caso de uso, y la ayuda se **regenera** desde
  ahí. Por eso no se edita el HTML a mano: la próxima generación lo pisaría.
- Un **bug** se anota además en [`doc/hallazgos/REGISTRO.md`](../../doc/hallazgos/REGISTRO.md), que
  es el registro único de hallazgos del proyecto, y ahí queda con su evidencia hasta que se corrige.

Cuando el issue se cierra, GitHub te avisa por mail y el comentario de cierre dice en qué PR entró.

---

## Cómo leer los casos para saber qué reportar

Los casos de uso están escritos en castellano en `doctest/features/<modulo>/`, un archivo `.feature`
por caso. **Dónde se leen:** en el navegador, desde GitHub, o en tu editor si tenés el repo clonado.
Se leen sin saber programar: cada uno tiene el flujo en pasos "Dado / Cuando / Entonces".

Si al leer uno ves que **falta un camino** que vos hacés todos los días, eso es exactamente un
test-gap.
