---
name: base64-file-handling
description: "Guía y estándar para el manejo de archivos e imágenes en Base64 en el ecosistema Trazalog / CodeIgniter basándose en form_helper.php (renderizado, stream_get_contents, prefijos data:mime, guardado en BD y previsualización)."
---

# Manejo de Archivos e Imágenes en Base64 (form_helper.php)

Usa esta guía técnica y estándar cada vez que necesites procesar, renderizar, descargar o almacenar archivos e imágenes codificados en Base64 en el sistema (CodeIgniter + PostgreSQL/MySQL), siguiendo el patrón establecido en `application/modules/traz-comp-formularios/helpers/form_helper.php`.

---

## 1. Arquitectura y Flujo de Datos

En el ecosistema de Trazalog:
- **Base de Datos:** Los archivos o imágenes se guardan como texto en base64 en columnas tipo `TEXT` o `BYTEA` (por convención `valor4_base64`), mientras que el nombre original del archivo con su extensión se guarda en `valor` (ej: `plano_tecnico.pdf`).
- **Backend (PHP):** 
  - Al recuperar de BD, si viene como recurso/LOB/stream de base de datos (ej. PostgreSQL bytea o resource PHP), se lee con `stream_get_contents($stream)` o `pg_unescape_bytea()`.
  - Se mapea la extensión del archivo (`obtenerExtension($nombreArchivo)`) al prefijo Data URI correspondiente (`data:mime/tipo;base64,`).
  - Al concatenar `Data URI + base64`, se obtiene una URL autocontenida que el navegador puede descargar o visualizar de inmediato sin necesidad de un endpoint extra de descarga física.
- **Frontend (HTML/JS):**
  - `<a href="data:..." download="archivo.ext">` para archivos descargables.
  - `<div style="background-image: url(data:image/...;base64,...)">` o `<img src="data:image/...">` para previsualización inmediata.

---

## 2. Detección y Mapeo MIME a Base64 (`obtenerExtension`)

Función estándar implementada en [form_helper.php](file:///c:/xampp/htdocs/traz-tools/application/modules/traz-comp-formularios/helpers/form_helper.php):

```php
function obtenerExtension($archivo){
    $ext = explode('.', $archivo);
    switch(strtolower(array_pop($ext))){
        case 'jpg':   $ext = 'data:image/jpg;base64,'; break;
        case 'png':   $ext = 'data:image/png;base64,'; break;
        case 'jpeg':  $ext = 'data:image/jpeg;base64,'; break;
        case 'jfif':  $ext = 'data:image/jpeg;base64,'; break;
        case 'pjpeg': $ext = 'data:image/pjpeg;base64,'; break;
        case 'wbmp':  $ext = 'data:image/vnd.wap.wbmp;base64,'; break;
        case 'webp':  $ext = 'data:image/webp;base64,'; break;
        case 'pdf':   $ext = 'data:application/pdf;base64,'; break;
        case 'doc':   $ext = 'data:application/msword;base64,'; break;
        case 'xls':   $ext = 'data:application/vnd.ms-excel;base64,'; break;
        case 'docx':  $ext = 'data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,'; break;
        case 'txt':   $ext = 'data:text/plain;base64,'; break;
        case 'csv':   $ext = 'data:text/csv;base64,'; break;
        default:      $ext = ""; break;
    }
    return $ext;
}
```

---

## 3. Renderizado de Archivos Genéricos (PDF, Docs, etc.)

Patrón de la función `archivo($e)`:

```php
function archivo($e)
{
    $file = null;

    // Si el registro ya posee archivo guardado en base de datos
    if (isset($e->valor) && !empty($e->valor4_base64)) {
        $ext = obtenerExtension($e->valor);
        
        // Si viene como recurso de stream o string
        $rec = is_resource($e->valor4_base64) 
            ? stream_get_contents($e->valor4_base64) 
            : $e->valor4_base64;
            
        $url = $ext . $rec;
        $file = " download='$e->valor' href='$url' ";
    } else {
        $file = "style='display: none;'";
    }

    return
        "<div class='".($e->columna ? $e->columna : 'col-md-12')."'>
            <div class='form-group'>
                <label>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
                <input class='form-control' id='$e->name' type='file' name='". ($e->multiple ? '-file-'.$e->name.'[]' : '-file-'.$e->name) . "' " . ($e->requerido ? req() : null). ">
                <p class='help-block show-file'>
                    <a $file class='help-button col-sm-4 download' title='Descargar' download>
                        <i class='fa fa-download'></i> Ver Adjunto
                    </a>
                </p>
            </div>
        </div>";
}
```

---

## 4. Renderizado de Imágenes con Preview

Patrón de la función `image($e)`:

```php
function image($e)
{
    $style = '';
    $indice = rand(500, 100000);

    if (isset($e->valor4_base64) && !empty($e->valor4_base64)) {
        $rec = is_resource($e->valor4_base64) 
            ? stream_get_contents($e->valor4_base64) 
            : $e->valor4_base64;
            
        $ext = obtenerExtension($e->valor);
        $style = "background-image: url($ext$rec);";
    } else {
        $style = "background-image: url(lib/imageForms/camera_2.png);";
    }

    return
    "<div class='".($e->columna ? $e->columna : 'col-md-12')."'>
        <label for='$e->label'>$e->label" . ($e->requerido ? "<strong class='text-danger'> *</strong>" : null) . ":</label>
        <div class='form-group imgConte centrar'>
            <label for='$indice'>
                <div class='imgEdit'>
                    <input class='form-control' value='" . (isset($e->valor) ? $e->valor : null) . "' type='file' id='$indice' name='". ($e->multiple ? '-file-'.$e->name.'[]' : '-file-'.$e->name) . "' " . ($e->requerido ? req() : null) . " onchange='previewFile(this)' accept='image/*' capture/>   
                </div>
                <div class='imgPreview'>
                    <div id='vistaPrevia_$indice' style='$style'></div>
                </div>
            </label>
        </div>
    </div>";
}
```

---

## 5. Recepción y Guardado en el Controlador / Modelo

### A. Detección en el Controlador (`Form::guardar`)
Los inputs de archivos llevan el prefijo `-file-` (ej: `-file-foto_herramienta`):
```php
foreach ($data as $key => $o) {
    if (strpos($key, 'file') !== false) {
        $nom = str_replace("-file-", "", $key);
        // Guardamos en 'valor' el nombre del archivo original
        $data[$nom] = $_FILES[$key]['name'];
        unset($data[$key]);
    }
}
```

### B. Conversión a Base64 en el Modelo (`Forms::guardar` / `Forms::actualizar`)
Se lee el archivo temporal subido por PHP y se codifica en Base64:
```php
// Archivo simple
if (isset($_FILES["-file-" . $key]['tmp_name']) && is_uploaded_file($_FILES["-file-" . $key]['tmp_name'])) {
    $valor4_base64 = base64_encode(file_get_contents($_FILES["-file-" . $key]['tmp_name']));
    $this->db->set('valor4_base64', $valor4_base64);
}

// O para múltiples archivos:
for ($i = 0; $i < count($_FILES[$nom]['name']); $i++) {
    if (!empty($_FILES[$nom]['tmp_name'][$i])) {
        $base64 = base64_encode(file_get_contents($_FILES[$nom]['tmp_name'][$i]));
        // Insertar registro con nombre en 'valor' y $base64 en 'valor4_base64'
    }
}
```

---

## 6. Previsualización en el Cliente (JavaScript)

Para que el usuario vea el archivo/imagen seleccionado antes de enviarlo:

```javascript
// Previsualizar imágenes (previewFile)
function previewFile(input) {
    if (input.files && input.files[0]) {
        var reader = new FileReader();
        reader.onload = function (e) {
            var targetPreview = $(input).closest('.imgConte').find('.imgPreview div');
            targetPreview.css('background-image', 'url(' + e.target.result + ')');
        };
        reader.readAsDataURL(input.files[0]);
    }
}

// Previsualizar / Descargar archivos genéricos
$('input[type="file"]').on("change", function (e) {
    if (e.target.files && e.target.files[0]) {
        var file = e.target.files[0];
        var link = $(this).closest(".form-group").find("a.download");
        var blob = new Blob([file]);
        var url = URL.createObjectURL(blob);

        link.attr({
            download: file.name,
            href: url
        }).show();
    }
});
```

---

## 7. Buenas Prácticas y Puntos Críticos

1. **Streams en BD:** En PostgreSQL o PDO, los campos `bytea` o `text` extensos frecuentemente devuelven un `resource` en PHP. Usar siempre `stream_get_contents($stream)` antes de concatenar con el prefijo MIME.
2. **Tamaño de Carga:** El contenido Base64 incrementa el peso del archivo en aproximadamente un 33%. Verificar las directivas `upload_max_filesize` y `post_max_size` en `php.ini`.
3. **Validación de Extensión:** Si una extensión no está contemplada en `obtenerExtension()`, el prefijo MIME quedará vacío y el navegador intentará abrirlo como texto plano o fallará la descarga. Asegurar agregar las extensiones necesarias en la función.
