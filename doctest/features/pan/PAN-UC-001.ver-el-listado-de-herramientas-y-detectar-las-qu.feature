# ⚠️ Generado por generators/catalog-to-feature.ts — no editar a mano.
# Fuente: catalogo/pan/PAN-UC-001.yaml (versión 1.0, validado 2026-09-25).
# Si algo está mal, se corrige el caso y se regenera con `npm run features`.

@pan @PAN-UC-001
Característica: Ver el listado de herramientas y detectar las que tienen certificación vencida

  Quién lo hace: Usuario
  Dónde: Herramientas → Herramientas

  Antecedentes:
    Dado Sesión iniciada en Tools
    Y El rol tiene asignado el menú de Herramientas

  Escenario: Camino principal
    Cuando Entra a Herramientas
    Entonces Se muestra la grilla con Acciones, Código, Tipo, Descripción, Modelo, Marca, Establecimiento/Pañol y Estado
    Y cuando Observa la columna Estado
    Entonces Cada herramienta muestra Activa, Entregada o Inhabilitada
    Y cuando Observa las herramientas con certificación próxima a vencer o vencida
    Entonces Las que tienen certificación por vencer muestran una alerta naranja; las que tienen alguna vencida, una roja. Cuando hay vencidas no se muestra además la naranja
    Y cuando Pasa el mouse sobre la alerta
    Entonces Se muestra la leyenda: 'Certificado por vencer' o 'Certificados vencidos'
    Y cuando Hace clic en la alerta
    Entonces Se abre el modal de certificaciones de esa herramienta

  Escenario: Filtrar solo lo que necesita atención
    Cuando Marca el filtro 'Cert. por vencer'
    Entonces La grilla queda solo con las herramientas que tienen alerta naranja o roja

  Escenario: Filtrar por ubicación o tipo
    Cuando Usa los filtros de Establecimiento, Pañol o Tipo de Herramienta
    Entonces La grilla se reduce a lo seleccionado

  # Reglas que este caso verifica:
  #   - El listado solo muestra herramientas de la empresa de la sesión
  #   - Los tres estados posibles son Activa, Entregada e Inhabilitada
  #   - Una certificación vencida tiene prioridad visual sobre una por vencer: se muestra la roja y no la naranja
  #   - El vencimiento avisa pero NO bloquea ninguna operación

  # Datos de prueba:
  #   empresa: EMPRESA_TEST_1
  #   precondicion: la empresa tiene herramientas en un pañol, al menos una con certificación por vencer y otra con certificación vencida
