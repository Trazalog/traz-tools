#!/usr/bin/env python3
"""
Verifica que ninguna consulta de los DataServices (.dbs) repita un parámetro con nombre.

Por qué: el WSO2 EI 6.5 de DEMO y producción no acepta que un mismo `:parametro` aparezca más de una
vez en el <sql> de una consulta. Falla con "Error in 'SQLQuery.processPreNormalQuery': null"
(NullPointerException) al armar la sentencia, en GET y en POST. El MI local sí lo acepta, así que en
desarrollo no se nota.

Cómo se escribe entonces: cada parámetro que hace falta más de una vez se liga una sola vez en una tabla
derivada y el resto de la consulta usa la columna, por ejemplo:
    SELECT ... FROM (SELECT :id_empresa AS p_id_empresa) param CROSS JOIN equipos e
    WHERE e.id_empresa = param.p_id_empresa AND EXISTS (... x.id_empresa = param.p_id_empresa)
En un UPDATE la derivada va primera:  UPDATE (SELECT ...) param CROSS JOIN tabla t ... SET ...

Uso (desde la raíz del repo):  python3 scripts/ci/dbs-sin-parametros-repetidos.py
Sale con 1 si encuentra alguna consulta nueva con parámetros repetidos.
"""
import glob
import re
import sys

CARPETA = '_backend/api/ToolsAPIProject/ToolsAPIProject/src/main/wso2mi/artifacts/data-services'

# Consultas que ya estaban así en master. No se tocan en este control; ver
# doc/migracion/MIGRACION-ASSETPLANNER.md (E67). Si se arreglan, sacarlas de acá.
CONOCIDAS = {
    ('ALMDataService.dbs', 'getStockFiltradoMcp'),
    ('MANDataService.dbs', 'getOTsByEmpresa'),
    ('semaresiduosDS.dbs', 'contEntregadosSet'),
}


def desescapar(x):
    return (x.replace('&#xd;', '\r').replace('&lt;', '<').replace('&gt;', '>')
            .replace('&quot;', '"').replace('&apos;', "'").replace('&amp;', '&'))


def repetidos(sql):
    sin_textos = re.sub(r"'(?:[^'\\]|\\.)*'", "''", sql)
    nombres = re.findall(r'(?<![:\w]):(\w+)', sin_textos)
    return sorted({n for n in nombres if nombres.count(n) > 1})


def main():
    malas = []
    for ruta in sorted(glob.glob(CARPETA + '/*.dbs')):
        archivo = ruta.rsplit('/', 1)[-1]
        texto = open(ruta, encoding='utf-8').read()
        for m in re.finditer(r'<query id="([^"]+)"[^>]*>(.*?)</query>', texto, re.S):
            sql = re.search(r'<sql>(.*?)</sql>', m.group(2), re.S)
            if not sql or (archivo, m.group(1)) in CONOCIDAS:
                continue
            rep = repetidos(desescapar(sql.group(1)))
            if rep:
                malas.append('%s · %s repite %s' % (archivo, m.group(1), ', '.join(':' + r for r in rep)))
    if malas:
        print('Consultas con parámetros repetidos (el EI 6.5 las rechaza):')
        for x in malas:
            print('  - ' + x)
        print('Ligá cada parámetro una sola vez en una tabla derivada "param". Ver el encabezado de este script.')
        return 1
    print('OK: ninguna consulta nueva repite parámetros.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
