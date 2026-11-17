---
name: Iconos de Acciones
description: Columna "Acciones" de los listados traz-tools con los íconos FontAwesome del sistema, tal como articulo/list.php: td con text-center text-light-blue, fa-search / fa-pencil / fa-times-circle, cursor pointer, margin 3px y title en español.
---

# Íconos de la columna Acciones

Patrón de referencia: `application/modules/traz-comp-almacenes/views/articulo/list.php`
(columna `Acciones`, `columnDefs` targets 0).

Plantilla: `templates/columna_acciones.js` (relativa a este `SKILL.md`).

## Regla principal

**El color va en el `<td>`, no en el ícono.**

```js
{
    'targets': [0],
    'createdCell': function (td, cellData, rowData, row, col) {
        $(td).attr('class', 'text-center text-light-blue');
    },
    'data': 'acciones',
    'render': function (data, type, row) {
        return '<i class="fa fa-search" style="cursor: pointer; margin: 3px;" title="Ver Detalles" onclick="ver(this);"></i>'
             + '<i class="fa fa-fw fa-pencil" style="cursor: pointer; margin: 3px;" title="Editar" onclick="editar(this)"></i>'
             + '<i class="fa fa-fw fa-times-circle" style="cursor: pointer; margin: 3px;" title="Eliminar" onclick="verificarStock(this)"></i>';
    }
}
```

`text-light-blue` es `#3c8dbc !important` (AdminLTE), el celeste por defecto de las acciones.
Los `<i>` **no** llevan `text-light-blue` ni `color:` inline: heredan del `td`.

## Set de íconos

| Acción           | Clase                          | `title`        |
| ---------------- | ------------------------------ | -------------- |
| Ver / Detalles   | `fa fa-search`                 | `Ver Detalles` |
| Editar           | `fa fa-fw fa-pencil`           | `Editar`       |
| Eliminar         | `fa fa-fw fa-times-circle`     | `Eliminar`     |
| Imprimir         | `fa fa-fw fa-print`            | `Imprimir`     |
| QR               | `fa fa-fw fa-qrcode`           | `QR`           |
| Detalle de stock | `fa fa-fw fa-search`           | `Detalle Stock`|
| Habilitar/Inhab. | `fa fa-fw fa-toggle-on/off`    | `Inhabilitar` / `Habilitar` |

`fa-fw` solo cuando hay **más de un ícono** en la celda: fija el ancho y los alinea en columna.
Si hay un único ícono por fila, usar la clase sin `fa-fw` (como `fa-search` en Ver).

## Detalles de markup

- Estilo inline exacto: `style="cursor: pointer; margin: 3px;"`.
- `title` siempre en español y describiendo la acción (es el tooltip nativo).
- Orden de los íconos: **Ver → Editar → (otras) → Eliminar**; eliminar siempre último.
- Click: `onclick="funcion(this)"` (patrón de `articulo/list.php`) o clases `.btnAlgo` con handler
  delegado (`$(document).off('click', '.btnX').on(...)`, patrón del skill `datatables-tools`).
  **No mezclar ambos en la misma celda.**
- Nunca agregar `font-size` al ícono: hereda el tamaño del texto de la tabla.
- **No copiar** el `<tr><td>...</td>` que devuelve el render de `articulo/list.php`: es un resto
  legacy e inserta HTML inválido dentro de la celda. Devolver solo los `<i>`.

## Definition de la columna

```php
<th width="15%">Acciones</th>
```

```js
'columnDefs': [
    { 'targets': '_all', 'defaultContent': '-' },
    {
        'targets': [0],
        'orderable': false,
        'searchable': false,
        'createdCell': function (td) { $(td).attr('class', 'text-center text-light-blue'); },
        'render': function (data, type, row) { /* íconos */ }
    }
]
```

Con la API moderna (objeto `columns`) el equivalente es **`createdCell`**, no `className`:

```js
'columns': [
    { 'data': null, 'orderable': false, 'searchable': false, 'className': 'text-center',
      'createdCell': function (td) { $(td).addClass('text-light-blue'); },
      'render': function (data, type, row) { /* íconos */ } },
    ...
]
```

**Cuidado:** `columns.className` en DataTables 1.10 se aplica a las celdas **y también al `th`**,
así que el título “Acciones” quedaría celeste. Por eso el color va con `createdCell`, que solo
corre sobre las celdas del cuerpo. El `className` se deja solo para lo que sí debe heredar el
encabezado (por ejemplo `text-center`).

## Verificación

1. `C:\xampp\php\php.exe -l <vista>`.
2. La celda muestra los íconos en celeste `#3c8dbc`, centrados, con 3px entre ellos.
3. Al pasar el mouse aparece el `title` correcto en cada ícono.
4. El click dispara la acción de esa fila (pasar `this` y leer la fila con `closest('tr')`).
5. En Excel/PDF/Imprimir la columna Acciones **no** debe exportarse (ver `exportOptions.columns`).
