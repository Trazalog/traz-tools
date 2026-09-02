# =============================================================================
# El flujo OAuth de Tools contra Dnato
# =============================================================================
# Verifica que los parametros que manda el chat del agente sean los que Dnato
# acepta, y que los errores vuelvan con el contrato que el controller espera.
#
# No completa el flujo: eso necesita una sesion de usuario en el navegador. Lo
# que si cubre es todo lo que se puede romper por un parametro mal armado, que
# es donde estan los errores dificiles de diagnosticar.
#
#   hurl --variable dnato=http://traz-comp.local/traz-comp-dnato \
#        --variable redirect=http://traz-comp.local/traz-tools/traz-comp-agente/agente/callback \
#        --test tests/agente/oauth-dnato.hurl
# =============================================================================

# --- El servidor de autorizacion se anuncia como esperamos -----------------
GET {{dnato}}/oauth/.well-known/oauth-authorization-server
HTTP 200
[Asserts]
jsonpath "$.authorization_endpoint" exists
jsonpath "$.token_endpoint" exists
# S256 es obligatorio del lado de Dnato: si desapareciera, el chat dejaria de
# poder conectarse.
jsonpath "$.code_challenge_methods_supported" contains "S256"
jsonpath "$.grant_types_supported" contains "authorization_code"
jsonpath "$.response_types_supported" contains "code"


# --- Las claves publicas estan disponibles ---------------------------------
GET {{dnato}}/oauth/.well-known/jwks.json
HTTP 200
[Asserts]
jsonpath "$.keys" isCollection
jsonpath "$.keys[0].alg" == "RS256"
jsonpath "$.keys[0].kid" exists


# --- Con los parametros del chat, Dnato manda a autenticar (no da error) ---
# Un 3xx aca significa que client_id, challenge y method son los correctos.
GET {{dnato}}/oauth/authorize?client_id=trazalog-mcp-connector&redirect_uri={{redirect}}&response_type=code&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&state=prueba
[Options]
location: false
HTTP 307


# --- Un client_id que no es el nuestro se rechaza --------------------------
GET {{dnato}}/oauth/authorize?client_id=cliente-inventado&redirect_uri={{redirect}}&response_type=code&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256
HTTP 400
[Asserts]
jsonpath "$.error" == "unauthorized_client"


# --- PKCE sin S256 se rechaza: el chat NO puede caer en 'plain' ------------
GET {{dnato}}/oauth/authorize?client_id=trazalog-mcp-connector&redirect_uri={{redirect}}&response_type=code&code_challenge=abc&code_challenge_method=plain
HTTP 400
[Asserts]
jsonpath "$.error" == "invalid_request"


# --- El endpoint de token solo acepta POST ---------------------------------
GET {{dnato}}/oauth/token
HTTP 405
[Asserts]
jsonpath "$.error" == "method_not_allowed"


# --- Solo authorization_code -----------------------------------------------
POST {{dnato}}/oauth/token
Content-Type: application/x-www-form-urlencoded
```
grant_type=password&code=x&code_verifier=y&client_id=trazalog-mcp-connector&redirect_uri={{redirect}}
```
HTTP 400
[Asserts]
jsonpath "$.error" == "unsupported_grant_type"


# --- Un code inventado se rechaza con invalid_grant ------------------------
# Es el error que el controller traduce a "No se pudo obtener la autorizacion".
POST {{dnato}}/oauth/token
Content-Type: application/x-www-form-urlencoded
```
grant_type=authorization_code&code=code-que-no-existe&code_verifier=verificador-cualquiera-de-largo-suficiente-para-pasar&client_id=trazalog-mcp-connector&redirect_uri={{redirect}}
```
HTTP 400
[Asserts]
jsonpath "$.error" == "invalid_grant"
