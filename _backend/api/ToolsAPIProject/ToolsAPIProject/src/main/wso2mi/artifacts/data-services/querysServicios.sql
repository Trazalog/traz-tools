
endpoint de Desarrollo
http://10.142.0.7:8280/services/COREDataService

endpoint de Test
http://10.142.0.3:8280/services/COREDataService


-- validaBPMCaseYEmpr(valida coincidencia entre Empresa y Caseid --COREDataService--)
  resurso: /bandeja/linea/validar/case_id/{case_id}/empr_id/{empr_id}
  metodo: get

  select case_id
  from core.case_empresa
  where case_id = cast(:case_id as INTEGER)
  and empr_id = cast(:empr_id as INTEGER)

  {"respuesta":{ "case_id":"$case_id" }}}








