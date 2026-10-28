#!/bin/bash
# Uso (terminal local, con un MI que tenga toolsNTFAPI + NTFDataService desplegados):
#   B=http://localhost:8310/tools/ntf bash tests/ntf/probar_api.sh
# Los JWT van sin firma: la sequence solo decodifica, la firma la valida el APIM antes de llegar al MI.
# Prueba de toolsNTFAPI en el MI de prueba (8310), con X-JWT-Assertion armados a mano.
B=${B:-http://localhost:8310/tools/ntf}; E=$((920000 + RANDOM))
jwt() { local p; p=$(printf '%s' "$1" | base64 -w0 | tr '+/' '-_' | tr -d '='); echo "eyJhbGciOiJub25lIn0.$p.firma"; }
ANA=$(jwt "{\"sub\":\"ana@carbon.super\",\"empr_id\":\"$E\"}")
BETO=$(jwt "{\"sub\":\"beto\",\"empr_id\":\"$E\"}")
OTRA=$(jwt "{\"sub\":\"ana\",\"empr_id\":\"$((E+1))\"}")
SINSUB=$(jwt "{\"empr_id\":\"$E\"}")
c() { local who=$1; shift; curl -s -w "  [%{http_code}]" -H "X-JWT-Assertion: $who" -H Accept:application/json "$@"; echo; }
j() { local who=$1; shift; c "$who" -H Content-Type:application/json "$@"; }
echo "empresa $E"
echo "-- ana registra su navegador";   j $ANA -X POST $B/dispositivos -d '{"token":"fcm:token-de-prueba-api-'$E'","plataforma":"web"}'
echo "-- token corto (400)";            j $ANA -X POST $B/dispositivos -d '{"token":"x"}'
echo "-- publicar (agente) a ana y beto, con empr_id falso en el cuerpo"; j $BETO -X POST $B/avisos -d '{"empr_id":"1","tipo":"stock_critico","titulo":"Reponer filtro","destinatarios":["ana","beto"],"emisor":"Quirqui","origen":"agente","dedupe_key":"d1"}'
echo "-- misma dedupe";                 j $BETO -X POST $B/avisos -d '{"tipo":"stock_critico","titulo":"Otra vez","destinatarios":"ana","dedupe_key":"d1"}'
echo "-- sin titulo (400)";             j $BETO -X POST $B/avisos -d '{"tipo":"stock_critico"}'
echo "-- sin sub (503)";                j $SINSUB -X POST $B/avisos -d '{"tipo":"x1","titulo":"t"}'
echo "-- sin JWT (503)";                curl -s -w "  [%{http_code}]\n" $B/avisos/mios
echo "-- campanita de ana";             c $ANA $B/avisos/mios
echo "-- no leidos de ana";             c $ANA $B/avisos/no-leidos
echo "-- ana en otra empresa (vacio)";  c $OTRA $B/avisos/mios
echo "-- id invalido (400)";            c $ANA -X POST $B/avisos/abc/leido
ID=$(curl -s -H "X-JWT-Assertion: $ANA" $B/avisos/mios | python3 -c 'import sys,json; print(json.load(sys.stdin)["avisos"]["aviso"][0]["aviso_id"])')
echo "-- ana marca $ID";                c $ANA -X POST $B/avisos/$ID/leido
echo "-- otra empresa marca $ID (0)";   c $OTRA -X POST $B/avisos/$ID/leido
echo "-- beto marca todo";              c $BETO -X POST $B/avisos/leidos
echo "-- no leidos ana / beto";         c $ANA $B/avisos/no-leidos; c $BETO $B/avisos/no-leidos
echo "-- beto da de baja el de ana (0)"; c $BETO -X DELETE "$B/dispositivos/fcm%3Atoken-de-prueba-api-$E"
echo "-- ana lo da de baja (1)";        c $ANA -X DELETE "$B/dispositivos/fcm%3Atoken-de-prueba-api-$E"
echo "-- en la base";
docker exec ntf-pg11-prueba psql -U postgres -d trazalog_tools -t -c "select a.aviso_id, a.empr_id, a.origen, a.emisor, (select string_agg(usuario||':'||leido, ',') from ntf.destino d where d.aviso_id=a.aviso_id) dest, (select count(*) from ntf.envio e where e.aviso_id=a.aviso_id) envios from ntf.aviso a where a.empr_id in ($E, 1) and a.dedupe_key='d1'" -c "select usuario, token, activo from ntf.dispositivo where empr_id=$E"
