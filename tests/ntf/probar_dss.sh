#!/bin/bash
# Uso (terminal local, con un MI que tenga NTFDataService desplegado y la base de prueba ntf-pg11-prueba):
#   B=http://localhost:8310/services/NTFDataService bash tests/ntf/probar_dss.sh
# Ojo: los GET van SIN Content-Type (con Content-Type: application/json el DSS ignora los parametros del path).
# Prueba de punta a punta de NTFDataService contra el MI de prueba (8310).
B=${B:-http://localhost:8310/services/NTFDataService}; E=$((900000 + RANDOM)); echo "empresa $E"
c() { curl -s -H Accept:application/json "$@"; echo; }
j() { curl -s -H Content-Type:application/json -H Accept:application/json "$@"; echo; }
echo "-- alta dispositivo ana"; j -X POST $B/dispositivo -d "{\"_post_dispositivo\":{\"empr_id\":\"$E\",\"usuario\":\"ana\",\"token\":\"fcm-token-de-prueba-mi-$E\"}}"
echo "-- publicar con dedupe"; j -X POST $B/aviso -d "{\"_post_aviso\":{\"empr_id\":\"$E\",\"origen\":\"alm\",\"tipo\":\"stock_critico\",\"titulo\":\"Reponer filtro\",\"destinatarios\":\"ana,beto\",\"emisor\":\"quirqui\",\"dedupe_key\":\"k1\"}}"
echo "-- misma dedupe (mismo id)"; j -X POST $B/aviso -d "{\"_post_aviso\":{\"empr_id\":\"$E\",\"origen\":\"alm\",\"tipo\":\"stock_critico\",\"titulo\":\"Repetido\",\"destinatarios\":\"ana\",\"dedupe_key\":\"k1\"}}"
echo "-- publicar minimo"; j -X POST $B/aviso -d "{\"_post_aviso\":{\"empr_id\":\"$E\",\"origen\":\"man\",\"tipo\":\"ot_vencida\",\"titulo\":\"OT 15 vencida\",\"destinatarios\":\"ana\"}}"
echo "-- avisos de ana"; c $B/avisos/emprid/$E/nick/ana
echo "-- no leidos ana"; c $B/avisos/noleidos/emprid/$E/nick/ana
echo "-- beto intenta marcar todo de ana? (marca solo lo suyo)"; j -X PUT $B/aviso/leido -d "{\"_put_aviso_leido\":{\"empr_id\":\"$E\",\"usuario\":\"beto\"}}"
echo "-- ana marca todo"; j -X PUT $B/aviso/leido -d "{\"_put_aviso_leido\":{\"empr_id\":\"$E\",\"usuario\":\"ana\"}}"
echo "-- no leidos ana"; c $B/avisos/noleidos/emprid/$E/nick/ana
echo "-- baja dispositivo de ana por beto (0) y por ana (1)"; j -X PUT $B/dispositivo/baja -d "{\"_put_dispositivo_baja\":{\"empr_id\":\"$E\",\"usuario\":\"beto\",\"token\":\"fcm-token-de-prueba-mi-$E\"}}"; j -X PUT $B/dispositivo/baja -d "{\"_put_dispositivo_baja\":{\"empr_id\":\"$E\",\"usuario\":\"ana\",\"token\":\"fcm-token-de-prueba-mi-$E\"}}"
echo "-- avisos de alguien sin avisos"; c $B/avisos/emprid/$E/nick/nadie
echo "-- titulo vacio (debe fallar)"; j -X POST $B/aviso -d "{\"_post_aviso\":{\"empr_id\":\"$E\",\"origen\":\"man\",\"tipo\":\"ot_vencida\",\"titulo\":\" \"}}" | cut -c1-200
echo "-- envios en la base"; docker exec ntf-pg11-prueba psql -U postgres -d trazalog_tools -t -c "select a.aviso_id, e.estado, d.usuario from ntf.envio e join ntf.aviso a using(aviso_id) left join ntf.dispositivo d using(dispositivo_id) where a.empr_id=$E"
