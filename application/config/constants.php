<?php
defined('BASEPATH') OR exit('No direct script access allowed');

/*
|--------------------------------------------------------------------------
| Display Debug backtrace
|--------------------------------------------------------------------------
|
| If set to TRUE, a backtrace will be displayed along with php errors. If
| error_reporting is disabled, the backtrace will not display, regardless
| of this setting
|
*/
defined('SHOW_DEBUG_BACKTRACE') OR define('SHOW_DEBUG_BACKTRACE', TRUE);

/*
|--------------------------------------------------------------------------
| File and Directory Modes
|--------------------------------------------------------------------------
|
| These prefs are used when checking and setting modes when working
| with the file system.  The defaults are fine on servers with proper
| security, but you may wish (or even need) to change the values in
| certain environments (Apache running a separate process for each
| user, PHP under CGI with Apache suEXEC, etc.).  Octal values should
| always be used to set the mode correctly.
|
*/
defined('FILE_READ_MODE')  OR define('FILE_READ_MODE', 0644);
defined('FILE_WRITE_MODE') OR define('FILE_WRITE_MODE', 0666);
defined('DIR_READ_MODE')   OR define('DIR_READ_MODE', 0755);
defined('DIR_WRITE_MODE')  OR define('DIR_WRITE_MODE', 0755);

/*
|--------------------------------------------------------------------------
| File Stream Modes
|--------------------------------------------------------------------------
|
| These modes are used when working with fopen()/popen()
|
*/
defined('FOPEN_READ')                           OR define('FOPEN_READ', 'rb');
defined('FOPEN_READ_WRITE')                     OR define('FOPEN_READ_WRITE', 'r+b');
defined('FOPEN_WRITE_CREATE_DESTRUCTIVE')       OR define('FOPEN_WRITE_CREATE_DESTRUCTIVE', 'wb'); // truncates existing file data, use with care
defined('FOPEN_READ_WRITE_CREATE_DESTRUCTIVE')  OR define('FOPEN_READ_WRITE_CREATE_DESTRUCTIVE', 'w+b'); // truncates existing file data, use with care
defined('FOPEN_WRITE_CREATE')                   OR define('FOPEN_WRITE_CREATE', 'ab');
defined('FOPEN_READ_WRITE_CREATE')              OR define('FOPEN_READ_WRITE_CREATE', 'a+b');
defined('FOPEN_WRITE_CREATE_STRICT')            OR define('FOPEN_WRITE_CREATE_STRICT', 'xb');
defined('FOPEN_READ_WRITE_CREATE_STRICT')       OR define('FOPEN_READ_WRITE_CREATE_STRICT', 'x+b');

/*
|--------------------------------------------------------------------------
| Exit Status Codes
|--------------------------------------------------------------------------
|
| Used to indicate the conditions under which the script is exit()ing.
| While there is no universal standard for error codes, there are some
| broad conventions.  Three such conventions are mentioned below, for
| those who wish to make use of them.  The CodeIgniter defaults were
| chosen for the least overlap with these conventions, while still
| leaving room for others to be defined in future versions and user
| applications.
|
| The three main conventions used for determining exit status codes
| are as follows:
|
|    Standard C/C++ Library (stdlibc):
|       http://www.gnu.org/software/libc/manual/html_node/Exit-Status.html
|       (This link also contains other GNU-specific conventions)
|    BSD sysexits.h:
|       http://www.gsp.com/cgi-bin/man.cgi?section=3&topic=sysexits
|    Bash scripting:
|       http://tldp.org/LDP/abs/html/exitcodes.html
|
*/
defined('EXIT_SUCCESS')        OR define('EXIT_SUCCESS', 0); // no errors
defined('EXIT_ERROR')          OR define('EXIT_ERROR', 1); // generic error
defined('EXIT_CONFIG')         OR define('EXIT_CONFIG', 3); // configuration error
defined('EXIT_UNKNOWN_FILE')   OR define('EXIT_UNKNOWN_FILE', 4); // file not found
defined('EXIT_UNKNOWN_CLASS')  OR define('EXIT_UNKNOWN_CLASS', 5); // unknown class
defined('EXIT_UNKNOWN_METHOD') OR define('EXIT_UNKNOWN_METHOD', 6); // unknown class member
defined('EXIT_USER_INPUT')     OR define('EXIT_USER_INPUT', 7); // invalid user input
defined('EXIT_DATABASE')       OR define('EXIT_DATABASE', 8); // database error
defined('EXIT__AUTO_MIN')      OR define('EXIT__AUTO_MIN', 9); // lowest automatically-assigned error code
defined('EXIT__AUTO_MAX')      OR define('EXIT__AUTO_MAX', 125); // highest automatically-assigned error code

#COMPONENTE FORMULARIOS
define('FRM', 'traz-comp-formularios/');
define('FILES', 'files/');

# DNATO
define('LOGIN', true);
define('DNATO', 'http://localhost/traz-comp-dnato/');

define('TOOLS_ADMIN_USER','admin@gmail.com');

define('PORT', ':3000/');

define('PRD', 'traz-prod-trazasoft/');
define('PLANIF_AVANZA_TAREA',true);

#COMPONENTE TST
define('TST', 'traz-comp-tareasestandar/');
define('TAREAS_DEFAULT_PROC', 'TST001');

#TRAZ-COMP-BPM
define('BPM', 'traz-comp-bpm/');

define('BONITA_URL', 'http://10.142.0.13:8080/bonita/');

define('BPM_PROCESS_ID_PEDIDOS_NORMALES', '8803232493891311406');
define('BPM_PROCESS_ID_PEDIDOS_EXTRAORDINARIOS', '6866538875650512673');
define('BPM_PROCESS_ID_TAREA_GENERICA', '5822241643386814582');
#YUDICA REPARACION_NEUMATICOS
define('BPM_PROCESS_ID_REPARACION_NEUMATICOS', '6450700179097987411');
#SICPOA Control de Ingreso de Camiones
define('BPM_PROCESS_ID_INGRESO_CAMIONES', '7654696702603905131');
#SEIN PROCESO PRODUCTIVO
define('BPM_PROCESS_ID_PROCESO_PRODUCTIVO', '6149765815561286114');
#TRAZ-TOOLS-MAN Proceso de Mantenimiento AssetPlanner
define('BPM_PROCESS_ID_MANTENIMIENTO', '8664799170016058315');
#SEMA-DESA-RESIDUOS Proceso de Solicitud de Contenedores
define('BPM_PROCESS_ID_SOLICITUD_CONTENEDORES', '8163057805246541677');
#SEMA-DESA-RESIDUOS Proceso de Solicitud de Retiro de Contenedores
define('BPM_PROCESS_ID_SOLICITUD_RETIRO_CONTENEDORES', '6929606572460285556');
#SEMA-DESA-RESIDUOS Proceso de Generacion Orden de Transporte
define('BPM_PROCESS_ID_ORDEN_TRANSPORTE', '5000318715739374358');

#YUDICA REPARACION_NEUMATICOS
define('YUDIPROC', 'yudi-tools-almproc/');

#SEIN -tools-ALM PAN TAR
define('SEIN', 'sein-tools-almpantar/');

#COMPONENTE PAÑOL
define('PAN', 'traz-comp-pan/');

#COMPONENTE ALMACENES
define('ALM', 'traz-comp-almacenes/');
define('viewOT', false);

#COMPONENTE SICPOA
define('SICP', 'ddpe-tools-pro/');

#COMPONENTE CODIGO_QR
define('COD', 'traz-comp-codigos/');

#COMPONENTE NOTIFICACIONES
define('NOTI', 'traz-comp-notificaciones/');

#COMPONENTE MANTENIMIENTO
define('MAN', 'traz-tools-man/');

#COMPONENTE RESIDUOS
define('RESI', 'traz-tools-resi/');

define('BPM_PROCESS', json_encode(array(
    BPM_PROCESS_ID_PROCESO_PRODUCTIVO => ['nombre' => 'Servicios Industriales - Proceso Productivo', 'color' => '#0275d8', 'proyecto'=>SEIN, 'model'=>'Proceso_tareas'],
    BPM_PROCESS_ID_REPARACION_NEUMATICOS => ['nombre' => 'Proceso de Reparación de Neumáticos', 'color' => '#0275d8', 'proyecto'=>YUDIPROC, 'model'=>'Yudiproctareas'],
    BPM_PROCESS_ID_PEDIDOS_NORMALES => ['nombre' => 'Ped. Materiales', 'color' => '#F39C12', 'proyecto'=>ALM, 'model'=>'Almtareas'],
    BPM_PROCESS_ID_PEDIDOS_EXTRAORDINARIOS => ['nombre' => 'Ped. Materiales Ext', 'color' => '#F39C12', 'proyecto'=>BPM, 'model'=>'Gentareas'],
    '6866538875650512673' => ['nombre' => 'Proc. Mantenimiento', 'color' => '#00A65A', 'proyecto'=>BPM, 'model'=>'Gentareas'],
    BPM_PROCESS_ID_TAREA_GENERICA  => ['nombre' => 'Tarea Genérica', 'color' => '#00A65A', 'proyecto'=>TST, 'model'=>'Tsttareas'],
    BPM_PROCESS_ID_INGRESO_CAMIONES  => ['nombre' => 'SICPOA', 'color' => '#00A65A', 'proyecto'=>SICP, 'model'=>'Sicpoatareas'],
    BPM_PROCESS_ID_SOLICITUD_CONTENEDORES => ['nombre' => 'TERSU-BPM01 - Solicitud de Contenedores', 'color' => '#FF3300', 'proyecto'=> RESI.'general/', 'model'=>'Pedidocontenedores'],
    BPM_PROCESS_ID_SOLICITUD_RETIRO_CONTENEDORES => ['nombre' => 'TERSU-BPM02 - Solicitud de Retiro de Contenedores', 'color' => '#ABC51A', 'proyecto'=> RESI.'general/', 'model'=>'Retirocontenedores'],
    BPM_PROCESS_ID_ORDEN_TRANSPORTE => ['nombre' => 'TERSU-BPM03 - Generación Orden de Transporte', 'color' => '#1A56C5', 'proyecto'=> RESI.'general/', 'model'=>'Entregaordentransportes']
)));

define('BPM_ADMIN_USER', 'admin');
define('BPM_ADMIN_PASS', '123traza');
define('BPM_USER_PASS', 'bpm');

#ERRORES DE BONITA
define('ASP_100', 'Fallo Conexión BPM');
define('ASP_101', 'Error al Inciar Proceso');
define('ASP_102', 'Error al Tomar Tarea');
define('ASP_103', 'Error al Soltar Tarea');
define('ASP_104', 'Error al Cerrar Tarea');
define('ASP_105', 'Error al Obtener Vista Global');
define('ASP_106', 'Error al Obtener Usuarios');
define('ASP_107', 'Error al Asignar Usuario');
define('ASP_108', 'Error al Guardar Comentarios');
define('ASP_109', 'Error de Loggin');
define('ASP_110', 'Error al Obtener Detalle Tarea');
define('ASP_111', 'Error al Obtener Bandeja de Tareas');
define('ASP_112', 'Error al Obtener Comentarios');
define('ASP_113', 'Usuario No Encontrado');
define('ASP_114', 'Error al Actualizar Variable');
define('ASP_115', 'Error al Leer Variable');



//Nombre de Proyecto
define('MNOM', 'Tools');
define('NOM', 'Trazalog Tools');

//Vista por Defecto
#define('DEF_VIEW',BPM.'Pedidotrabajo/dash');
define('DEF_VIEW',BPM.'Proceso');

//Proceso pedido trabajo standar
define('PRO_STD', 'PROCESO-STANDAR');

//TAREA ejecutada por Bonita automaticamente
define('TAREA_IT','Ejecuta el Trabajo - Tools Tareas');

/*
|--------------------------------------------------------------------------
| Variables HOST y REST
|--------------------------------------------------------------------------
|
| Variables Locales
|http://10.142.0.13:8280/tools/bpm/groups/123
*/
define('HOST', 'http://10.142.0.13:8280');
define('RESTPT', HOST.'/services/produccionTest/'); //(3 reservicios sin resolver)
define('API_URL', HOST.'/tools/log');
define('REST_ALM', HOST.'/services/ALMDataService');
define('REST_PRD', HOST.'/services/PRDDataService');
define('REST_BPM', HOST.'/tools/bpm');
define('REST_CORE', HOST.'/services/COREDataService');
define('REST_FRM', HOST.'/services/FRMDataService');
define('REST_PRD_LOTE', HOST.'/services/PRDLoteDataService');
define('REST_PRD_ETAPAS', HOST.'/services/PRDEtapaDataService');
define('REST_LOG', HOST.'/services/LOGDataService');
define('REST_PRD_NOCON', HOST.'/services/PRDNoConsumiblesDataService');
define('REST_TST', HOST.'/services/TARDataService');
define('REST_API_BPM', HOST.'/tools/bpm/proceso/instancia');
define('REST_TDS', HOST.'/services/TrazabilidadDataService');
define('REST_PRO', HOST.'/services/PRODataService');
define('REST_COD', HOST.'/services/QRDataService');
define('REST_PAN', HOST.'/services/PANDataService');
define('REST_SICP', HOST.'/services/ddpeSicpoaDataService');
define('API_SICP', HOST.'/sicpoa/api');
define('API_BASCULA','http://localhost:8290/tools/bascula/pesar');
define('REST_RESI', HOST.'/services/semaresiduosDS');
define('REST_PRD_RESI', HOST.'/services/sema/PRDDataService');


define('REST_SEIN', HOST.'/services/SeinDataService');

#TRAZ-COMP-CALENDAR
define('DURACION_JORNADA', '08:00');
define('HORA_FIN_JORNADA', '18:00');
define('HORA_INICIO_JORNADA','10:00');

#TOKEN_API_MANAGER TEST
define('TOKEN_API_MANAGER','eyJ4NXQiOiJOMkpqTWpOaU0yRXhZalJrTnpaalptWTFZVEF4Tm1GbE5qZzRPV1UxWVdRMll6YzFObVk1TlEiLCJraWQiOiJNREpsTmpJeE4yRTFPR1psT0dWbU1HUXhPVEZsTXpCbU5tRmpaalEwWTJZd09HWTBOMkkwWXpFNFl6WmpOalJoWW1SbU1tUTBPRGRpTkRoak1HRXdNQV9SUzI1NiIsImFsZyI6IlJTMjU2In0.eyJzdWIiOiJhZG1pbiIsImF1dCI6IkFQUExJQ0FUSU9OIiwiYXVkIjoib0wwRGVMNEZWZnpOOE1CUlRiSmloZXROMGtzYSIsIm5iZiI6MTY5MTUxMzk3OSwiYXpwIjoib0wwRGVMNEZWZnpOOE1CUlRiSmloZXROMGtzYSIsInNjb3BlIjoiZGVmYXVsdCIsImlzcyI6Imh0dHBzOlwvXC9sb2NhbGhvc3Q6OTQ0M1wvb2F1dGgyXC90b2tlbiIsImV4cCI6MzE1NTI5MTUxMzk3OSwiaWF0IjoxNjkxNTEzOTc5LCJqdGkiOiI0NDZjOGNhZS03OTY4LTRkMTEtYTBmOC1hNzYwYTRmYWFhMmEifQ.bxi2644U9HNwyYqFyqI77WnIxhG7SFSXLbXMiQM4A3_jiRQM6rH4Yq8TiQfaapTg9knsIrRe2A-ZTOwKMkJkV8csM8w0c53sOlm0cAOyYG8A9BWqamoFu82m9AH3kuoDreegYRg_O5bBq2CloHiviTMteU1l3XSJMt-GY5czgVkgVmbeoAU3I58XJcvz7WfyRTCti557VcSab-Tkw9PNhUvs4c4EYJXrevXUneKl8VeglXdjigWgJBkbetuMwroEB1BBkDgW9-0bLHeT2HfYheuQzv5Nhp-So9dq6zE2mXsllrvwpExy1GJsHvHLTzloJr26Vj0GTgHR0HOFekpm8A');

#ROWS DATATABLE
define('DT_SIZE_ROWS', false);

#Empresas que les aparecera los formularios de mantenimiento autonomo
define('EMPRESAS_FORM', 1);