<?php if (!defined('BASEPATH')) exit('No direct script access allowed');
/**
* Representa la entidad
*
* @autor Hugo Gallardo
*/
class Dashs extends CI_Model {
  /**
  *
  * @param
  * @return
  */
  function __construct(){
    parent::__construct();
  }

  /**
  * Devuelve items menu
  * @param
  * @return array items de menu y permisos de distintos tipos de usuarios
  */
  function obtenerMenu(){
    log_message("DEBUG","#TRAZA | CORE | Dashs | obtenerMenu()");
    $email = $this->session->userdata('email');
    $grupo = $this->session->userdata('groupBpm');;
    $aux = $this->rest->callAPI("GET",REST_CORE."/menuitems/porEmail/$email/porGrupo/".urlencode($grupo));
    $aux =json_decode($aux["data"]);
    return $aux;
  }

  /**
  * Obtiene las memberships por id de user en BPM para perfil
  * @param
  * @return
  */
  function obtenerMemberships(){
    $userIdBpm = userIdBpm();
    $aux = $this->rest->callAPI("GET",REST_BPM."/memberships/xUserid/".$userIdBpm."/session/dd");
    $aux = json_decode($aux["data"]);
    $memb = $aux->payload;
    return $memb;
  }
  /**
  * Devuelve array con memberships y empr_id
  * @param array devuelto con info de BPM
  * @return array ordenado con membrerhips
  */
  function armarMembership($data){

    $roleBPM = "";
    $groupBPM = "";

    foreach ($data as $value) {

      $roleBPM = $value->role_id->name;
      $groupBPM = $value->group_id->displayName;

      $nom = explode("-", $value->group_id->name);
      $empr_id = $nom[0];
      $key = $empr_id;
      $opciones[$key] = $groupBPM . " - " . $roleBPM;
    }

    return $opciones;

  }

  /**
  * Cuenta los usuarios generados para la empresa actual.
  * Usa el endpoint existente GET /users/{empr_id} (getUsersXGroup) y cuenta del lado del cliente
  * — supuesto A4: no requiere query nueva ni deploy de API.
  * @return int|null cantidad, o null si no se pudo obtener
  */
  function contarUsuariosEmpresa(){
    $empr_id = empresa();
    if(empty($empr_id)){
      return null;
    }
    try {
      $resp = $this->rest->callAPI("GET", REST_CORE."/users/".$empr_id);
      if(!isset($resp["data"])){
        return null;
      }
      $data = json_decode($resp["data"]);
      if(!isset($data->usuarios) || !isset($data->usuarios->usuario)){
        return 0;
      }
      $usuarios = $data->usuarios->usuario;
      // el DataService devuelve objeto suelto si hay un solo usuario, array si hay varios
      return is_array($usuarios) ? count($usuarios) : 1;
    } catch (Exception $e) {
      log_message('ERROR', '#TRAZA | CORE | Dashs | contarUsuariosEmpresa() >> '.$e->getMessage());
      return null;
    }
  }

  /**
  * ¿El usuario logueado es Administrador de la empresa activa?
  * Se resuelve contra Postgres (seg.memberships_users), que es la fuente autoritativa del rol
  * — NO contra las memberships de Bonita, que guardan el rol funcional activo (Almacen, Mantenedor,
  * etc.), nunca 'Administrador'. Ver doc/analisis/dashboard-administrador-landing.md (A1).
  * @return bool
  */
  function esAdminEmpresa(){
    $email = $this->session->userdata('email');
    $empr_id = empresa();
    if(empty($email) || empty($empr_id)){
      return false;
    }
    try {
      $resp = $this->rest->callAPI("GET", REST_CORE."/usuario/esadmin/porEmail/".rawurlencode($email)."/empresa/".$empr_id);
      if(!isset($resp["data"])){
        return false;
      }
      $data = json_decode($resp["data"]);
      return isset($data->respuesta->es_admin)
          && ($data->respuesta->es_admin === 'true' || $data->respuesta->es_admin === true);
    } catch (Exception $e) {
      log_message('ERROR', '#TRAZA | CORE | Dashs | esAdminEmpresa() >> '.$e->getMessage());
      return false;
    }
  }

  /**
  * Lee un KPI de la caché (kpi.cache) via ToolsKPIDataService para la empresa actual.
  * El tablero SIEMPRE lee de acá, nunca del DataService de negocio (ver Fase 2 del doc de análisis).
  * @param string $nombre nombre del KPI en la caché
  * @return array ['valor'=>..,'valor_json'=>mixed,'calculado_en'=>..] o [] si no hay dato
  */
  function obtenerKPI($nombre){
    $empr_id = empresa();
    if(empty($empr_id) || empty($nombre)){
      return array();
    }
    try {
      $resp = $this->rest->callAPI("GET", REST_KPI."/kpi/".rawurlencode($nombre)."/emprid/".$empr_id);
      if(!isset($resp["data"])){
        return array();
      }
      $data = json_decode($resp["data"]);
      if(!isset($data->kpi)){
        return array();
      }
      $kpi = $data->kpi;
      $valor_json = null;
      if(isset($kpi->valor_json) && $kpi->valor_json !== '' && $kpi->valor_json !== null){
        $valor_json = json_decode($kpi->valor_json); // valor_json viene como texto (jsonb::text)
      }
      return array(
        'nombre'       => isset($kpi->nombre) ? $kpi->nombre : $nombre,
        'valor'        => isset($kpi->valor) ? $kpi->valor : null,
        'valor_json'   => $valor_json,
        'calculado_en' => isset($kpi->calculado_en) ? $kpi->calculado_en : null,
      );
    } catch (Exception $e) {
      log_message('ERROR', '#TRAZA | CORE | Dashs | obtenerKPI() >> '.$e->getMessage());
      return array();
    }
  }

  /**
  * Devuelve el nombre visible de la empresa actual a partir de las memberships.
  * @param array $memberships payload de obtenerMemberships()
  * @return string
  */
  function nombreEmpresaActual($memberships){
    $empr_id = (string) empresa();
    if(!empty($memberships) && is_array($memberships)){
      foreach($memberships as $m){
        if(is_object($m) && isset($m->group_id)){
          $nom = isset($m->group_id->name) ? explode("-", $m->group_id->name) : array();
          $id_grupo = isset($nom[0]) ? (string) $nom[0] : '';
          if($id_grupo === $empr_id && isset($m->group_id->displayName)){
            return (string) $m->group_id->displayName;
          }
        }
      }
      // fallback: primer displayName disponible
      foreach($memberships as $m){
        if(is_object($m) && isset($m->group_id) && isset($m->group_id->displayName)){
          return (string) $m->group_id->displayName;
        }
      }
    }
    return 'Tu empresa';
  }

}