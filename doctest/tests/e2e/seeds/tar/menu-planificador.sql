-- ───────────────────────────────────────
-- Seed de DocTest TAR: menús del módulo de Tareas para el rol "Planificador de Tareas".
--
-- Por qué existe: el alta de empresa le deja a ese rol solo la opción `TAR|tareas`, que no abre
-- ninguna pantalla. En una empresa real lo completa su administrador desde DNATO → Gestión de
-- Menues (decisión del 2026-10-27, doc/specs/TAR-bugs-detectados.md §6). Este seed hace lo mismo
-- en la empresa recién creada por el modo full, que no tiene quién lo haga a mano.
--
-- `indicador_eficiencia` va a propósito: es la primera opción del grupo y, sin ella, el menú lateral
-- se invierte y esconde las demás (H-109).
--
-- Es idempotente. Dónde se ejecuta: lo corre `npm run doctest -- full`; a mano, PC con VPN:
--   psql -v empresa='<nombre de la empresa>' -f doctest/tests/e2e/seeds/tar/menu-planificador.sql
-- ───────────────────────────────────────

INSERT INTO seg.memberships_menues (modulo, opcion, "group", role, usuario_app)
SELECT 'TAR', o.opcion, :'empresa', 'Planificador de Tareas ' || :'empresa', 'doctest'
FROM (VALUES ('tareas_grupo'), ('indicador_eficiencia'), ('pedidotrabajo'), ('planificacion_tarea'), ('tareas_std')) AS o(opcion)
WHERE NOT EXISTS (
  SELECT 1 FROM seg.memberships_menues m
  WHERE m.modulo = 'TAR' AND m.opcion = o.opcion
    AND m.role = 'Planificador de Tareas ' || :'empresa' AND m.eliminado = 0
);
