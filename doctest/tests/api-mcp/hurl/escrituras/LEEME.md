# Las dos tools que escriben

`alm_crear_pedido_materiales` y `man_create_ot` **crean registros reales e instancian procesos en
Bonita**. Por eso viven en este subdirectorio: `hurl/*.hurl` no los alcanza, así que la suite normal
**nunca** los corre por accidente.

> 🔴 **Nunca contra producción** (RNF-04). Y tampoco contra un ambiente compartido sin avisar: cada
> corrida deja un pedido o una orden que alguien va a ver en su bandeja.

Para correrlos, explícitamente y con las variables de datos completas:

```bash
hurl --test --variables-file env/staging-v3.env hurl/escrituras/*.hurl
```

Hacen falta, además de las de la suite normal: `arti_id_test`, `depo_id_test` y `equipo_id_test`.

Todo lo que crean lleva el prefijo **`TEST`** en el texto libre, para poder encontrarlo después.
