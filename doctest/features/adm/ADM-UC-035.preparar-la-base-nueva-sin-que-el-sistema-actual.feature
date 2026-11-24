# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/adm/ADM-UC-035.yaml (versión 1.0, validado 2026-11-24).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.
# Test que lo implementa: tests/e2e/specs/adm/ADM-UC-035.preparar-base.spec.ts

@adm @ADM-UC-035
Característica: Preparar la base nueva sin que el sistema actual note nada

  Quién lo hace: Usuario
  Dónde: Ingreso → tablero de Tools → menú lateral · DNATO → Usuarios

  Antecedentes:
    Dado El script de base corrió en el ambiente de prueba
    Y Usuario de la empresa DocTest con roles de operación

  Escenario: Camino principal
    Cuando Ingresa a Tools con el mismo usuario que antes de correr el script
    Entonces Entra igual que antes, a la misma empresa
    Y cuando Mira el menú lateral de Tools
    Entonces Tiene exactamente las mismas opciones, en el mismo orden, que antes del script
    Y cuando Trabaja en una pantalla de su operación (por ejemplo, el listado de equipos)
    Entonces Funciona igual que antes

  Escenario: Registración de una empresa nueva
    Cuando Un visitante registra una empresa nueva después del script
    Entonces La registración termina igual que antes, y la empresa nueva queda activa

  Escenario: Membresías
    Cuando Después del script, se revisa el estado de todas las membresías existentes
    Entonces Todas están en estado activo; las que no coinciden con ninguna empresa por el nombre están en el listado que recibe Rodolfo

  Escenario: Catálogo
    Cuando Después del script, se revisan las opciones de menú existentes
    Entonces Todas están publicadas y de tipo pantalla, con su texto de siempre

  Escenario: Administración de DNATO
    Cuando El administrador abre la lista de usuarios de DNATO y la de empresas
    Entonces Las ve igual que antes

  Escenario: Vuelta atrás
    Cuando En el ambiente de prueba se corre el script de vuelta atrás
    Entonces Desaparece solo lo que agregó el script, y Tools y DNATO siguen funcionando

  # Reglas que este caso verifica:
  #   - El script solo agrega: el ingreso, el menú y las pantallas de operación funcionan igual
  #   - El menú de Tools de cada usuario es el mismo antes y después
  #   - La registración funciona igual después del script
  #   - Toda membresía existente queda activa y las que no se unen a una empresa por el nombre se listan
  #   - Toda opción de menú existente queda publicada y de tipo pantalla
  #   - DNATO funciona igual
  #   - El script tiene vuelta atrás que borra solo lo agregado

  # Datos de prueba:
  #   usuario: uno de los usuarios por defecto de la empresa DocTest
  #   ambiente: copia de DEMO, nunca producción
