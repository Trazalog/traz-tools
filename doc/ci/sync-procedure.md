# Procedimiento: Sincronización semanal develop → develop-v3

**Tarea relacionada:** E7-CICD-06  
**Script:** `scripts/dev/sync-v2-to-v3.sh`

---

## Por qué existe este proceso

Mientras v2 está en soporte activo (`develop`) y v3 en desarrollo paralelo (`develop-v3`), los bugfixes aplicados a v2 deben propagarse a v3 periódicamente para evitar que las ramas diverjan demasiado. Si no se sincroniza, el merge final del cutover (v3 → producción) acumula conflictos difíciles de resolver.

Ver estrategia completa en [`doc/v3/TRAZALOG_v3_CICD_STRATEGY.md`](../v3/TRAZALOG_v3_CICD_STRATEGY.md) sección 2.

---

## Cuándo correr el script

**Cada lunes a las 09:00 (hora Argentina, UTC-3)**, antes de iniciar trabajo nuevo.

Condiciones previas:
- Working tree limpio (sin cambios sin commitear).
- Acceso de push a `origin/develop-v3` (requiere permisos de administrador de la rama protegida, o bien temporalmente desactivar la protección).

---

## Cómo ejecutar

```bash
cd /ruta/al/repo
bash scripts/dev/sync-v2-to-v3.sh
```

El script:
1. Hace `git fetch origin` para traer el estado remoto actualizado.
2. Verifica que no hay cambios sin commitear.
3. Cambia a `develop-v3` y hace `pull`.
4. Detecta cuántos commits nuevos tiene `develop` respecto a `develop-v3`.
5. Si hay commits nuevos: hace `merge --no-ff` con mensaje `chore: sync v2 fixes from develop`.
6. Si no hay nada nuevo: termina sin crear commit.
7. Hace `push origin develop-v3`.

---

## Qué hacer si hay conflictos

El script falla en `git merge` con `exit code 1` y el repo queda en estado de merge pendiente.

```
CONFLICTO (contenido): Conflicto de fusión en application/some/file.php
Fusión automática fallida; arregle los conflictos y luego realice un commit con el resultado.
```

Pasos para resolver:

```bash
# 1. Ver archivos en conflicto
git status

# 2. Resolver cada conflicto manualmente (editá los archivos)
#    Mantener la versión de v3 donde haya diferencias arquitectónicas importantes.
#    Para fixes de v2 que aplican directamente, aceptar los cambios de develop.

# 3. Marcar como resueltos y commitear
git add <archivos-resueltos>
git commit -m "chore: sync v2 fixes from develop (conflictos resueltos manualmente)"

# 4. Push
git push origin develop-v3
```

Si el conflicto es complejo (toca código que fue refactorizado en v3), crear un issue con la descripción del conflicto y resolverlo en una sesión de pair review.

---

## Cómo verificar que la sync salió bien

Después de que el script termine exitosamente:

```bash
# Verificar que develop-v3 incluye todos los commits de develop
git log --oneline origin/develop-v3..origin/develop
# Salida esperada: (vacía — nada que esté en develop y no en develop-v3)

# Ver el merge commit creado
git log --oneline -3 origin/develop-v3
# El commit más reciente debe ser "chore: sync v2 fixes from develop"
```

También podés verificar en GitHub: en la página de `develop-v3` debe aparecer el merge commit con timestamp del lunes.

---

## Historial de sincronizaciones

| Fecha | Commits mergeados | Conflictos | Ejecutado por |
|---|---|---|---|
| (pendiente primera ejecución) | — | — | — |
