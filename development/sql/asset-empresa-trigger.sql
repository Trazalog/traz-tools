-- =============================================================================
--  asset-empresa-trigger.sql — grupos y permisos por empresa en AssetPlanner
-- =============================================================================
--
--  QUE ES
--    El trigger y el procedure que, cada vez que se da de alta una empresa en la
--    base de AssetPlanner (`assetv2`), le crean sus CINCO grupos de usuarios con
--    sus permisos de menu. Los invoca `POST /empresa` de toolsCOREAPI sin saberlo:
--    el trigger es AFTER INSERT sobre `empresas`.
--
--  POR QUE ESTA ACA
--    Hasta el 2026-09-10 vivian UNICAMENTE en la base del DEMO. Si se recreaba el
--    ambiente se perdian, y el alta de empresa quedaba creando empresas sin grupos
--    —o sea usuarios que entran y no ven ningun menu— sin que nada lo avisara.
--    `toolsCOREAPI.xml` ya apuntaba a este archivo en un comentario, pero el
--    archivo no existia.
--
--  DONDE SE EJECUTA
--    A mano, contra la base `assetv2` de la instalacion, con un cliente MySQL o
--    DBeaver. NO lo despliega el script: no es un artefacto de WSO2.
--
--      mysql -h <host> -u <usuario> -p assetv2 < asset-empresa-trigger.sql
--
--    Es reejecutable: hace DROP IF EXISTS antes de crear.
--
--  QUE HAY QUE SABER ANTES DE TOCARLO
--
--    · Los cinco grupos son fijos POR NOMBRE, no por id: `sisgroups.grpId` es
--      AUTO_INCREMENT, asi que cada empresa estrena los suyos. El `Admin` de una
--      empresa NO tiene el mismo numero que el de otra. Todo lo que necesite
--      referirse a un grupo debe resolverlo por `(id_empresa, grpName)`.
--
--    · El grupo `Almacen` se deja SIN ACCIONES a proposito. Quien caiga ahi entra
--      a AssetPlanner pero ve el menu vacio. Por eso el mapeo de roles de Tools
--      manda a `Responsable de Almacen` y `Responsable de Pañol` a `Solicitante`
--      y no a `Almacen`.
--
--    · Los `menuAccId` son ids de `sismenuactions` DE ESTA BASE. No son portables
--      entre instalaciones: si se migra a otra base hay que remapearlos.
--
--    · Para sumar o quitar permisos a un grupo, modificar UNICAMENTE los INSERT
--      de `sisgroupsactions` de la seccion 2. Los grupos existentes no se
--      actualizan solos: el procedure corre una vez, al crear la empresa.
--
--  Volcado del 2026-09-10 desde la base del DEMO.
-- =============================================================================

DROP TRIGGER IF EXISTS `trg_empresas_after_insert`;
DROP PROCEDURE IF EXISTS `sp_create_empresa_groups_and_actions`;

DELIMITER $$

CREATE PROCEDURE `sp_create_empresa_groups_and_actions`(IN p_empr_id INT)
BEGIN
    DECLARE v_admin_id       INT;
    DECLARE v_supervisor_id  INT;
    DECLARE v_solicitante_id INT;
    DECLARE v_mantenedor_id  INT;
    DECLARE v_almacen_id     INT;

    -- ==========================================================
    -- == 1) GRUPOS FIJOS (sisgroups)                           ==
    -- ==========================================================
    INSERT INTO sisgroups (grpName, grpDash, id_empresa)
        VALUES ('Admin', 'Equipo', p_empr_id);
    SET v_admin_id = LAST_INSERT_ID();

    INSERT INTO sisgroups (grpName, grpDash, id_empresa)
        VALUES ('Supervisor de Taller', 'Tarea', p_empr_id);
    SET v_supervisor_id = LAST_INSERT_ID();

    INSERT INTO sisgroups (grpName, grpDash, id_empresa)
        VALUES ('Solicitante', 'Sservicio', p_empr_id);
    SET v_solicitante_id = LAST_INSERT_ID();

    INSERT INTO sisgroups (grpName, grpDash, id_empresa)
        VALUES ('Mantenedor', 'Tarea', p_empr_id);
    SET v_mantenedor_id = LAST_INSERT_ID();

    INSERT INTO sisgroups (grpName, grpDash, id_empresa)
        VALUES ('Almacen', 'Tarea', p_empr_id);
    SET v_almacen_id = LAST_INSERT_ID();

    -- ==========================================================
    -- == 2) ACCIONES POR GRUPO (sisgroupsactions)              ==
    -- ==========================================================
    -- Cada bloque agrega los menuAccId que le corresponden al
    -- grpId recién creado. Para sumar/quitar permisos a grupos
    -- nuevos, modificar únicamente estos INSERT.
    -- ----------------------------------------------------------

    -- ---- Admin ------------------------------------------------
    INSERT INTO sisgroupsactions (grpId, menuAccId) VALUES
        (v_admin_id,   6), (v_admin_id,   7), (v_admin_id,   8), (v_admin_id,   9), (v_admin_id,  10),
        (v_admin_id,  11), (v_admin_id,  12), (v_admin_id,  13), (v_admin_id,  14), (v_admin_id,  18),
        (v_admin_id,  23), (v_admin_id,  24), (v_admin_id,  25), (v_admin_id, 151), (v_admin_id,  26),
        (v_admin_id,  27), (v_admin_id,  28), (v_admin_id,  29), (v_admin_id,  30), (v_admin_id,  31),
        (v_admin_id,  32), (v_admin_id,  33), (v_admin_id,  34), (v_admin_id,  35), (v_admin_id,  36),
        (v_admin_id,  37), (v_admin_id,  38), (v_admin_id,  39), (v_admin_id,  40), (v_admin_id,  41),
        (v_admin_id,  42), (v_admin_id,  43), (v_admin_id,  94), (v_admin_id,  95), (v_admin_id,  96),
        (v_admin_id, 115), (v_admin_id, 116), (v_admin_id, 117), (v_admin_id, 155), (v_admin_id, 156),
        (v_admin_id, 157), (v_admin_id, 118), (v_admin_id, 119), (v_admin_id, 120), (v_admin_id, 152),
        (v_admin_id, 153), (v_admin_id, 154), (v_admin_id, 177), (v_admin_id, 178), (v_admin_id, 179),
        (v_admin_id, 180), (v_admin_id, 209), (v_admin_id, 210), (v_admin_id, 211), (v_admin_id, 212),
        (v_admin_id,  64), (v_admin_id,  65), (v_admin_id,  66), (v_admin_id,  67), (v_admin_id,  68),
        (v_admin_id,  69), (v_admin_id,  70), (v_admin_id,  71), (v_admin_id,  72), (v_admin_id,  73),
        (v_admin_id,  74), (v_admin_id,  75), (v_admin_id,  85), (v_admin_id,  86), (v_admin_id,  87),
        (v_admin_id,  88), (v_admin_id,  89), (v_admin_id,  90), (v_admin_id,  91), (v_admin_id,  92),
        (v_admin_id,  93), (v_admin_id,  97), (v_admin_id,  98), (v_admin_id,  99), (v_admin_id, 100),
        (v_admin_id, 101), (v_admin_id, 102), (v_admin_id, 103), (v_admin_id, 104), (v_admin_id, 105),
        (v_admin_id, 106), (v_admin_id, 107), (v_admin_id, 108), (v_admin_id, 109), (v_admin_id, 110),
        (v_admin_id, 111), (v_admin_id, 170), (v_admin_id, 171), (v_admin_id, 172), (v_admin_id, 181),
        (v_admin_id, 182), (v_admin_id, 183), (v_admin_id, 184), (v_admin_id, 185), (v_admin_id, 186),
        (v_admin_id, 187), (v_admin_id, 188), (v_admin_id, 189), (v_admin_id, 190), (v_admin_id, 191),
        (v_admin_id, 192), (v_admin_id, 193), (v_admin_id, 194), (v_admin_id, 195), (v_admin_id, 196),
        (v_admin_id, 197), (v_admin_id, 198), (v_admin_id, 199), (v_admin_id, 200), (v_admin_id, 201),
        (v_admin_id, 202), (v_admin_id, 203), (v_admin_id, 204), (v_admin_id, 205), (v_admin_id, 206),
        (v_admin_id, 207), (v_admin_id, 208), (v_admin_id, 238), (v_admin_id, 239), (v_admin_id, 240),
        (v_admin_id, 241), (v_admin_id, 246), (v_admin_id, 247), (v_admin_id, 248), (v_admin_id, 249),
        (v_admin_id, 130), (v_admin_id, 132), (v_admin_id, 139), (v_admin_id, 140), (v_admin_id, 141),
        (v_admin_id, 142), (v_admin_id, 143), (v_admin_id, 144), (v_admin_id, 258), (v_admin_id, 259),
        (v_admin_id, 260), (v_admin_id, 261), (v_admin_id,  45), (v_admin_id,  46), (v_admin_id,  47),
        (v_admin_id, 214), (v_admin_id,  48), (v_admin_id,  49), (v_admin_id,  50), (v_admin_id, 215),
        (v_admin_id,  54), (v_admin_id,  55), (v_admin_id,  56), (v_admin_id, 217), (v_admin_id,  57),
        (v_admin_id,  58), (v_admin_id,  59), (v_admin_id,  60), (v_admin_id,  79), (v_admin_id,  80),
        (v_admin_id,  81), (v_admin_id, 225), (v_admin_id, 121), (v_admin_id, 122), (v_admin_id, 123),
        (v_admin_id, 218), (v_admin_id, 242), (v_admin_id, 243), (v_admin_id, 244), (v_admin_id, 245);

    -- ---- Supervisor de Taller ---------------------------------
    INSERT INTO sisgroupsactions (grpId, menuAccId) VALUES
        (v_supervisor_id,  23), (v_supervisor_id,  24), (v_supervisor_id,  25), (v_supervisor_id, 151),
        (v_supervisor_id, 226), (v_supervisor_id,  26), (v_supervisor_id,  27), (v_supervisor_id,  28),
        (v_supervisor_id, 227), (v_supervisor_id,  29), (v_supervisor_id,  30), (v_supervisor_id,  31),
        (v_supervisor_id, 228), (v_supervisor_id,  32), (v_supervisor_id,  33), (v_supervisor_id,  34),
        (v_supervisor_id, 230), (v_supervisor_id,  41), (v_supervisor_id,  42), (v_supervisor_id,  43),
        (v_supervisor_id, 233), (v_supervisor_id, 115), (v_supervisor_id, 116), (v_supervisor_id, 117),
        (v_supervisor_id, 155), (v_supervisor_id, 156), (v_supervisor_id, 157), (v_supervisor_id, 152),
        (v_supervisor_id, 153), (v_supervisor_id, 154), (v_supervisor_id, 176), (v_supervisor_id, 177),
        (v_supervisor_id, 178), (v_supervisor_id, 179), (v_supervisor_id, 180), (v_supervisor_id, 209),
        (v_supervisor_id, 210), (v_supervisor_id, 211), (v_supervisor_id, 212), (v_supervisor_id,  85),
        (v_supervisor_id,  86), (v_supervisor_id,  87), (v_supervisor_id,  88), (v_supervisor_id,  89),
        (v_supervisor_id,  90), (v_supervisor_id, 100), (v_supervisor_id, 101), (v_supervisor_id, 102),
        (v_supervisor_id, 170), (v_supervisor_id, 171), (v_supervisor_id, 172), (v_supervisor_id, 181),
        (v_supervisor_id, 182), (v_supervisor_id, 183), (v_supervisor_id, 184), (v_supervisor_id, 185),
        (v_supervisor_id, 186), (v_supervisor_id, 187), (v_supervisor_id, 188), (v_supervisor_id, 189),
        (v_supervisor_id, 190), (v_supervisor_id, 191), (v_supervisor_id, 192), (v_supervisor_id, 193),
        (v_supervisor_id, 194), (v_supervisor_id, 195), (v_supervisor_id, 196), (v_supervisor_id, 197),
        (v_supervisor_id, 198), (v_supervisor_id, 199), (v_supervisor_id, 200), (v_supervisor_id, 201),
        (v_supervisor_id, 202), (v_supervisor_id, 203), (v_supervisor_id, 204), (v_supervisor_id, 238),
        (v_supervisor_id, 239), (v_supervisor_id, 240), (v_supervisor_id, 241), (v_supervisor_id, 139),
        (v_supervisor_id, 140), (v_supervisor_id, 141), (v_supervisor_id, 142), (v_supervisor_id, 143),
        (v_supervisor_id, 144), (v_supervisor_id, 258), (v_supervisor_id, 259), (v_supervisor_id, 260),
        (v_supervisor_id, 261), (v_supervisor_id, 242), (v_supervisor_id, 243), (v_supervisor_id, 244),
        (v_supervisor_id, 245);

    -- ---- Solicitante ------------------------------------------
    INSERT INTO sisgroupsactions (grpId, menuAccId) VALUES
        (v_solicitante_id, 226), (v_solicitante_id,  29), (v_solicitante_id,  30), (v_solicitante_id,  31),
        (v_solicitante_id, 228), (v_solicitante_id,  32), (v_solicitante_id,  33), (v_solicitante_id,  34),
        (v_solicitante_id, 230), (v_solicitante_id,  41), (v_solicitante_id,  42), (v_solicitante_id,  43),
        (v_solicitante_id, 233), (v_solicitante_id, 209), (v_solicitante_id, 210), (v_solicitante_id, 211),
        (v_solicitante_id, 212), (v_solicitante_id, 242), (v_solicitante_id, 243), (v_solicitante_id, 244),
        (v_solicitante_id, 245);

    -- ---- Mantenedor -------------------------------------------
    INSERT INTO sisgroupsactions (grpId, menuAccId) VALUES
        (v_mantenedor_id,  29), (v_mantenedor_id,  30), (v_mantenedor_id,  32), (v_mantenedor_id,  33),
        (v_mantenedor_id, 115), (v_mantenedor_id, 116), (v_mantenedor_id, 209), (v_mantenedor_id, 210),
        (v_mantenedor_id, 242), (v_mantenedor_id, 243), (v_mantenedor_id, 244), (v_mantenedor_id, 245);

    -- ---- Almacen (sin acciones, igual que en producción) ------
    -- Se deja sin INSERT deliberadamente. Agregar acciones aquí
    -- en el futuro si el negocio lo requiere.

END$$

CREATE TRIGGER `trg_empresas_after_insert`
AFTER INSERT ON `empresas`
FOR EACH ROW
BEGIN
    CALL sp_create_empresa_groups_and_actions(NEW.id_empresa);
END$$

DELIMITER ;
