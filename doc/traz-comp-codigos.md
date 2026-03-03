# TRAZ-COMP-CODIGOS - Documentación del Módulo

El módulo **traz-comp-codigos** es un componente especializado del sistema Trazalog Tools.

## SOBRE TRAZALOG TOOLS:

- **Arquitectura**: Sistema modular basado en CodeIgniter 3.x con estructura MVC, donde cada módulo es independiente
- **Stack Tecnológico**: PHP + PostgreSQL/MySQL, integración con WSO2 ESB, Bonita BPM, y múltiples servicios externos
- **Enfoque Principal**: Trazabilidad completa de productos desde materias primas hasta productos finales
- **Características Clave**: Control de producción, gestión de lotes, integración BPM, reportes avanzados, y sistema de roles granular
- **Patrones de Desarrollo**: Validación de sesiones, logging detallado (#TRAZA), helpers reutilizables, y respuestas JSON consistentes
- **Configuración Regional**: Sistema configurado para Argentina (San Juan) con timezone específico

---

## 1. OBJETIVO FUNCIONAL DEL MÓDULO

El módulo **traz-comp-codigos** es un componente especializado del sistema Trazalog Tools que proporciona funcionalidades para:

- **Generación de Códigos QR**: Creación de códigos QR con diferentes formatos y configuraciones para identificación de productos, lotes, no consumibles y otros elementos del sistema
- **Gestión de URLs con Tokens**: Generación de enlaces seguros con tokens únicos para acceso controlado a funcionalidades específicas del sistema
- **Trazabilidad Visual**: Facilitar la identificación rápida y el seguimiento de elementos mediante códigos QR que contienen información estructurada
- **Integración con Módulos**: Proporcionar servicios de generación de códigos QR y URLs tokenizadas para ser utilizados por otros módulos del sistema (producción, almacenes, mantenimiento, etc.)

El módulo actúa como un servicio centralizado que permite a otros componentes del sistema generar códigos QR y URLs seguras sin necesidad de implementar esta lógica en cada módulo.

---

## 2. DESCRIPCIÓN DE PRINCIPALES LIBRERÍAS Y COMPONENTES

### 2.1 Librerías Externas

#### PHP QR Code Library (phpqrcode)
- **Ubicación**: `application/libraries/codigo_qr/phpqrcode/`
- **Descripción**: Librería PHP para generación de códigos QR
- **Clase Principal**: `QRcode`
- **Método Principal**: `QRcode::png()` - Genera código QR como imagen PNG
- **Parámetros Configurables**:
  - `$level`: Nivel de corrección de errores (L, M, Q, H)
  - `$pixel`: Tamaño de píxel
  - `$framSize`: Tamaño del borde en blanco

### 2.2 Componentes del Módulo

#### Controladores

**Codigo.php**
- **Función**: Gestión de generación de códigos QR
- **Métodos Principales**:
  - `generarQR()`: Genera QR estándar con labels
  - `generarQRlite()`: Genera QR sin labels (para no consumibles)
  - `generarQRMasivo()`: Genera múltiples QRs con nombres únicos

**Url.php**
- **Función**: Gestión de URLs con tokens
- **Métodos Principales**:
  - `index()`: Resuelve token y redirige a URL configurada
  - `generarLink()`: Genera nuevo token y URL asociada

#### Modelos

**Codigos.php**
- **Función**: Lógica de negocio para generación de códigos QR
- **Métodos**:
  - `generarQR($data, $config, $dir)`: Genera QR estándar
  - `generarQRlite($data, $config, $dir)`: Genera QR simplificado
  - `generarQRMasivo($data, $config, $dir)`: Genera QR con nombre único

**Urls.php**
- **Función**: Lógica de negocio para gestión de URLs tokenizadas
- **Métodos**:
  - `obtener($token)`: Obtiene URL asociada a un token
  - `obtenerUrls()`: Obtiene todas las URLs configuradas
  - `guardar($funcionalidad, $id, $token)`: Guarda nuevo token

### 2.3 Integraciones

- **WSO2 ESB**: Para comunicación con servicios REST de tokens
- **CodeIgniter REST Library**: Para llamadas a APIs externas
- **Sistema de Archivos**: Para almacenamiento de imágenes QR generadas

---

## 3. CASOS DE USO QUE CUBRE EL SUBMÓDULO

### 3.1 Caso de Uso 1: Generación de Código QR para Lote de Producción

**Descripción**: Generar un código QR que identifique un lote de producción con información completa (título y datos estructurados).

**Actores**: 
- Usuario del sistema (operario, supervisor)
- Módulo de Producción (traz-prod-trazasoft)

**Flujo**:
1. El usuario solicita generar QR para un lote
2. El módulo de producción llama a `Codigo::generarQR()`
3. Se genera el código QR con información del lote
4. Se guarda en directorio específico
5. Se retorna la URL del QR generado

**Información Incluida en QR**:
- Título del lote
- Batch ID
- Fecha de creación
- Producto asociado
- Establecimiento
- Etapa de producción

### 3.2 Caso de Uso 2: Generación de Código QR para No Consumible

**Descripción**: Generar un código QR simplificado (sin labels) para identificar no consumibles en el sistema.

**Actores**:
- Usuario del sistema
- Módulo de Producción/Mantenimiento

**Flujo**:
1. El usuario solicita generar QR para un no consumible
2. El módulo llama a `Codigo::generarQRlite()`
3. Se genera QR con solo el valor (sin labels)
4. Se guarda en directorio específico
5. Se retorna la URL del QR generado

**Información Incluida en QR**:
- Solo el código/identificador del no consumible (sin formato con labels)

### 3.3 Caso de Uso 3: Generación Masiva de Códigos QR

**Descripción**: Generar múltiples códigos QR con nombres únicos para evitar sobrescritura en generaciones masivas.

**Actores**:
- Usuario del sistema
- Módulo que requiere generación masiva

**Flujo**:
1. El usuario solicita generación masiva de QRs
2. El módulo llama a `Codigo::generarQRMasivo()` múltiples veces
3. Cada QR se genera con nombre único (incluye random)
4. Se guardan en directorio específico
5. Se retornan las URLs de los QRs generados

**Características Especiales**:
- Nombres únicos con random para evitar colisiones
- Permite generar múltiples QRs sin sobrescribir

### 3.4 Caso de Uso 4: Generación de URL con Token para Acceso Seguro

**Descripción**: Generar un enlace seguro con token único que permite acceso controlado a funcionalidades específicas del sistema.

**Actores**:
- Usuario del sistema
- Sistema de notificaciones (para envío por email)

**Flujo**:
1. El usuario solicita generar link para una funcionalidad
2. El sistema llama a `Url::generarLink()`
3. Se genera token único (MD5 hash)
4. Se guarda token asociado a funcionalidad e ID
5. Se retorna URL completa con token
6. El usuario accede a la URL con token
7. El sistema valida token y redirige a funcionalidad

**Uso Típico**:
- Envío de links por email para aprobaciones
- Acceso directo a tareas BPM
- Links temporales para reportes

### 3.5 Caso de Uso 5: Resolución de Token y Redirección

**Descripción**: Resolver un token recibido en URL y redirigir al usuario a la funcionalidad configurada.

**Actores**:
- Usuario (que hace clic en link con token)
- Sistema de autenticación

**Flujo**:
1. Usuario accede a URL con token
2. Sistema llama a `Url::index()` con token
3. Se busca token en base de datos
4. Se obtiene URL de redirección asociada
5. Se reemplazan parámetros dinámicos ({id})
6. Se redirige al usuario a la URL final

**Validaciones**:
- Token debe existir en base de datos
- Token debe estar asociado a una funcionalidad válida
- Si token inválido, se muestra error 7000

---

## 4. DIAGRAMAS DE ACTIVIDADES

### 4.1 Diagrama: Generación de Código QR para Lote de Producción

```mermaid
sequenceDiagram
    participant U as Usuario
    participant EP as Etapa.php<br/>(Producción)
    participant C as Codigo.php<br/>(Controlador)
    participant M as Codigos.php<br/>(Modelo)
    participant QR as PHP QR Code<br/>(Librería)
    participant FS as Sistema<br/>de Archivos

    U->>EP: Solicita generar QR para lote
    EP->>C: POST generarQR(data, config, direccion)
    C->>M: generarQR(data, config, dir)
    
    M->>FS: Verifica/Crea directorio
    FS-->>M: Directorio listo
    
    M->>M: Sanitiza nombre archivo<br/>(reemplaza caracteres especiales)
    M->>M: Construye contenido QR<br/>(título + datos estructurados)
    
    M->>QR: QRcode::png(contenido, filename, level, pixel, framSize)
    QR->>FS: Genera imagen PNG
    FS-->>QR: Imagen guardada
    QR-->>M: QR generado
    
    M->>M: Agrega random a filename<br/>(para evitar caché)
    M-->>C: Retorna {data, filename, dir}
    C-->>EP: JSON con URL del QR
    EP-->>U: Muestra QR generado
```

### 4.2 Diagrama: Generación de Código QR Lite para No Consumible

```mermaid
sequenceDiagram
    participant U as Usuario
    participant NC as NoConsumible<br/>(Controlador)
    participant C as Codigo.php<br/>(Controlador)
    participant M as Codigos.php<br/>(Modelo)
    participant QR as PHP QR Code<br/>(Librería)
    participant FS as Sistema<br/>de Archivos

    U->>NC: Solicita generar QR<br/>para no consumible
    NC->>C: POST generarQRlite(data, config, direccion)
    C->>M: generarQRlite(data, config, dir)
    
    M->>FS: Verifica/Crea directorio
    FS-->>M: Directorio listo
    
    M->>M: Sanitiza nombre archivo
    M->>M: Construye contenido QR<br/>(SOLO el valor, sin labels)
    
    M->>QR: QRcode::png(contenido, filename, level, pixel, framSize)
    QR->>FS: Genera imagen PNG
    FS-->>QR: Imagen guardada
    QR-->>M: QR generado
    
    M->>M: Agrega random a filename
    M-->>C: Retorna {data, filename, dir}
    C-->>NC: JSON con URL del QR
    NC-->>U: Muestra QR simplificado
```

### 4.3 Diagrama: Generación Masiva de Códigos QR

```mermaid
sequenceDiagram
    participant U as Usuario
    participant Mod as Módulo<br/>Solicitante
    participant C as Codigo.php<br/>(Controlador)
    participant M as Codigos.php<br/>(Modelo)
    participant QR as PHP QR Code<br/>(Librería)
    participant FS as Sistema<br/>de Archivos

    U->>Mod: Solicita generación<br/>masiva de QRs
    loop Para cada elemento
        Mod->>C: POST generarQRMasivo(data, config, direccion)
        C->>M: generarQRMasivo(data, config, dir)
        
        M->>FS: Verifica/Crea directorio
        FS-->>M: Directorio listo
        
        M->>M: Genera nombre único<br/>(título + random + "_QR.png")
        M->>M: Sanitiza nombre archivo
        M->>M: Construye contenido QR
        
        M->>QR: QRcode::png(contenido, filename, level, pixel, framSize)
        QR->>FS: Genera imagen PNG<br/>(con nombre único)
        FS-->>QR: Imagen guardada
        QR-->>M: QR generado
        
        M-->>C: Retorna {data, filename, dir}
        C-->>Mod: JSON con URL del QR
    end
    Mod-->>U: Lista de QRs generados
```

### 4.4 Diagrama: Generación de URL con Token para Acceso Seguro

```mermaid
sequenceDiagram
    participant U as Usuario
    participant Mod as Módulo<br/>Solicitante
    participant C as Url.php<br/>(Controlador)
    participant M as Urls.php<br/>(Modelo)
    participant WSO2 as WSO2 ESB<br/>(API REST)
    participant DB as Base de<br/>Datos

    U->>Mod: Solicita generar link<br/>para funcionalidad
    Mod->>C: POST generarLink(funcion, id)
    C->>C: Genera token único<br/>(MD5 hash complejo)
    
    C->>M: guardar(funcionalidad, id, token)
    M->>M: Prepara payload POST
    M->>WSO2: POST /token<br/>{funcionalidad, empr_id, id, token, usuario}
    WSO2->>DB: INSERT token en tabla urls
    DB-->>WSO2: Token guardado
    WSO2-->>M: Respuesta OK
    M-->>C: Token guardado exitosamente
    
    C->>C: Construye URL completa<br/>(base_url + /traz-comp-codigos/Url?token=...)
    C-->>Mod: JSON {url: "..."}
    Mod-->>U: Retorna URL con token<br/>(para enviar por email/notificación)
```

### 4.5 Diagrama: Resolución de Token y Redirección

```mermaid
sequenceDiagram
    participant U as Usuario
    participant C as Url.php<br/>(Controlador)
    participant M as Urls.php<br/>(Modelo)
    participant WSO2 as WSO2 ESB<br/>(API REST)
    participant DB as Base de<br/>Datos
    participant Dest as Funcionalidad<br/>Destino

    U->>C: GET /traz-comp-codigos/Url?token=xxx
    C->>C: Extrae token de query string
    
    C->>M: obtener(token)
    M->>WSO2: GET /token/{token}
    WSO2->>DB: SELECT * FROM urls WHERE token = ?
    DB-->>WSO2: Datos de funcionalidad
    WSO2-->>M: JSON {funcionalidad: {url, id}}
    M-->>C: Objeto con URL e ID
    
    alt Token válido
        C->>C: Reemplaza {id} en URL<br/>con ID obtenido
        C->>C: Construye URL completa<br/>(base_url + url_procesada)
        C->>Dest: redirect(url_completa)
        Dest-->>U: Muestra funcionalidad<br/>solicitada
    else Token inválido
        C-->>U: Error 7000-Token_invalido
    end
```

### 4.6 Diagrama de Actividad Completo: Flujo End-to-End de Generación y Uso de QR

```mermaid
flowchart TD
    Start([Usuario solicita<br/>generar QR]) --> Check{¿Tipo de QR?}
    
    Check -->|QR Estándar| QR1[generarQR]
    Check -->|QR Lite| QR2[generarQRlite]
    Check -->|QR Masivo| QR3[generarQRMasivo]
    
    QR1 --> Validate[Validar datos<br/>y configuración]
    QR2 --> Validate
    QR3 --> Validate
    
    Validate --> CreateDir{¿Directorio<br/>existe?}
    CreateDir -->|No| MkDir[Crear directorio<br/>con permisos 0777]
    CreateDir -->|Sí| Sanitize
    MkDir --> Sanitize[Sanitizar nombre<br/>archivo]
    
    Sanitize --> BuildContent{¿Tipo QR?}
    BuildContent -->|Estándar| Content1[Construir contenido<br/>con título y labels]
    BuildContent -->|Lite| Content2[Construir contenido<br/>solo con valor]
    BuildContent -->|Masivo| Content3[Construir contenido<br/>con título y labels<br/>+ nombre único]
    
    Content1 --> Generate[QRcode::png<br/>Generar imagen]
    Content2 --> Generate
    Content3 --> Generate
    
    Generate --> Save[Guardar imagen<br/>en sistema de archivos]
    Save --> AddCache[Agregar random<br/>a filename para evitar caché]
    AddCache --> Return[Retornar URL<br/>del QR generado]
    
    Return --> Display[Mostrar QR<br/>al usuario]
    Display --> End([Fin])
    
    style Start fill:#e1f5ff
    style End fill:#e1f5ff
    style Generate fill:#fff4e1
    style Save fill:#fff4e1
```

### 4.7 Diagrama de Actividad Completo: Flujo End-to-End de URLs con Token

```mermaid
flowchart TD
    Start([Solicitud de generar link]) --> GetParams[Obtener funcionalidad e ID]
    
    GetParams --> GenerateToken[Generar token único MD5 hash complejo]
    
    GenerateToken --> PreparePayload[Preparar payload con datos de token]
    
    PreparePayload --> CallAPI[Llamar WSO2 API POST /token]
    
    CallAPI --> SaveDB{¿Token guardado?}
    
    SaveDB -->|Error| ErrorNode[Retornar error]
    SaveDB -->|OK| BuildURL[Construir URL completa base_url + path + token]
    
    BuildURL --> ReturnURL[Retornar URL al solicitante]
    
    ReturnURL --> Send[Enviar URL por email/notificación]
    
    Send --> UserClick([Usuario hace clic en link])
    
    UserClick --> ExtractToken[Extraer token de query string]
    
    ExtractToken --> ValidateToken[Validar token en base de datos]
    
    ValidateToken --> TokenValid{¿Token válido?}
    
    TokenValid -->|No| ErrorToken[Error 7000 Token inválido]
    TokenValid -->|Sí| GetURL[Obtener URL de funcionalidad]
    
    GetURL --> ReplaceParams[Reemplazar parámetros id con valor real]
    
    ReplaceParams --> Redirect[Redirigir a funcionalidad destino]
    
    Redirect --> Show[Mostrar funcionalidad al usuario]
    
    Show --> End([Fin])
    
    ErrorNode --> End
    ErrorToken --> End
    
    style Start fill:#e1f5ff
    style End fill:#e1f5ff
    style GenerateToken fill:#fff4e1
    style ValidateToken fill:#fff4e1
    style Redirect fill:#e8f5e9
```

---

## NOTAS TÉCNICAS ADICIONALES

### Configuración de Códigos QR

Los parámetros de configuración típicos incluyen:
- **pixel**: Tamaño de píxel (ej: 4, 6, 8)
- **level**: Nivel de corrección de errores (L, M, Q, H)
- **framSize**: Tamaño del borde en blanco (ej: 2, 4)
- **titulo**: Título que aparece en el QR

### Sanitización de Nombres de Archivo

El sistema reemplaza caracteres especiales que pueden causar problemas en nombres de archivo:
- `/`, `:`, `*`, `|`, `<`, `>`, `?`, `"`, espacios → `_`

### Gestión de Tokens

- Los tokens se generan usando MD5 de combinación de:
  - `uniqid()`
  - `microtime()`
  - `rand()`
  - `date('m/d/Y h:i:s a', time())`
- Esto garantiza tokens únicos y seguros
- Los tokens se almacenan en base de datos asociados a funcionalidades e IDs específicos

### Integración con Otros Módulos

El módulo es utilizado por:
- **traz-prod-trazasoft**: Para QRs de lotes y no consumibles
- **yudi-tools-almproc**: Para QRs de pedidos de trabajo
- **sein-tools-almpantar**: Para QRs específicos de SEIN
- Cualquier módulo que necesite generar QRs o URLs tokenizadas

---

## CONCLUSIÓN

El módulo **traz-comp-codigos** es un componente esencial del sistema Trazalog Tools que proporciona servicios centralizados de generación de códigos QR y gestión de URLs seguras. Su diseño modular permite que otros componentes del sistema utilicen estas funcionalidades sin duplicar código, manteniendo consistencia en la generación de códigos y la gestión de accesos seguros mediante tokens.

