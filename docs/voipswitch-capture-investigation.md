# Investigación: captura de datos de VoIPSwitch (Windows Server 2012 R2)

Documento de campo a partir de un laboratorio real con **VoIPSwitch 2.x** sobre **Windows Server 2012 R2**. Objetivo: saber **dónde vive la configuración MySQL** y cómo obtener un dump usable para recuperación ante desastre **sin detener** el softswitch.

> Este documento **no** incluye contraseñas, tokens OAuth, dumps SQL ni rutas de clientes. Solo métodos y hallazgos reproducibles.

---

## 1. Pregunta de negocio

En un corte o migración, ¿podemos reconstruir la base `voipswitch` en otro servidor sabiendo solo lo que el propio VoIPSwitch ya tiene en disco?

Respuesta corta: **sí**, si leemos los XML de configuración y usamos `mysqldump` en caliente con flags seguros.

---

## 2. Mapa de instalación observado

Raíces típicas en hosts 2012 R2 (x86):

| Ruta | Qué hay |
|------|---------|
| `C:\Program Files (x86)\VoipSwitch\VoipSwitch 2.0\` | Binarios + `voipswitch_config.xml` |
| `...\VSM\Database.config` | Config alternativa de DB (params `conn*`) |
| `C:\Program Files (x86)\VoipBox 3.0\` | VoipBox / configs asociados |
| `C:\MySQL\bin\mysqldump.exe` | Cliente dump histórico (MySQL 5.0.x en labs antiguos) |

Atajos del escritorio de `Administrator` suelen apuntar a la consola VSM / VoipSwitch y ayudan a confirmar la carpeta real cuando hay varias copias.

---

## 3. Dónde están las credenciales MySQL

### 3.1 `voipswitch_config.xml` (prioridad alta)

Estructura observada (simplificada):

```xml
<vpsconfig>
  <database>
    <param name="ipaddr" value="127.0.0.1" />
    <param name="port" value="3306" />
    <param name="username" value="..." />
    <param name="password" value="***" />
    <param name="dbname" value="voipswitch" />
  </database>
</vpsconfig>
```

### 3.2 `Database.config` / `DatabaseIF.config`

Parámetros con claves tipo:

- `connhost`, `connport`, `connuser`, `connpassword`, `conndbname`

### 3.3 `voipbox_config.xml`

Misma familia de `<param name="..." value="...">` bajo nodo de base de datos.

**Regla de descubrimiento usada por PortalVoIPBackupAgent:** buscar por nombre preferido en las raíces conocidas; parsear XML; si falta `dbname`, asumir `voipswitch`.

---

## 4. Analizador (herramientas de laboratorio)

Scripts PowerShell **solo lectura** incluidos en `tools/`:

| Script | Función |
|--------|---------|
| `Find-VoipSwitchConfigs.ps1` | Inventario de raíces y archivos de config |
| `Find-MySQLConfigHits.ps1` | Lista archivos que mencionan mysql/password (solo rutas) |
| `Peek-DbConfig-Redacted.ps1` | Muestra XML con passwords enmascarados `***` |
| `List-DesktopShortcuts.ps1` | Resuelve accesos directos del escritorio |

En el binario Go:

```bat
PortalVoIPBackupAgent.exe diagnose
```

Imprime `source`, `host`, `port`, `user`, `db` y **`pass_len`** — nunca la clave.

---

## 5. Captura segura del dump

Flags usados (compatibles con MySQL 5.0 / laboratorios VoIPSwitch):

```text
mysqldump --host=... --port=... --user=...
  --single-transaction --quick --routines --hex-blob
  --result-file=<stamp>.sql
  <dbname>
```

Luego zip del `.sql` y borrado del SQL en claro cuando el zip está OK.

**No hacer en producción viva sin criterio:**

- Parar el servicio MySQL o VoipSwitch “para asegurar el dump”
- Hardcodear la password en un `.ps1` versionado
- Subir el `.sql` / `.zip` a un repo público

---

## 6. Hallazgos operativos (lab WS2012 R2)

1. **La fuente de verdad de la DB no es un `.env` moderno**: está en XML legacy dentro del árbol de instalación.
2. **`mysqldump` a menudo no está en PATH**; hay que probar `C:\MySQL\bin\mysqldump.exe` y rutas `Program Files\MySQL\...`.
3. **Guest Additions / carpetas compartidas** (`Y:\`, etc.) son útiles en VirtualBox para sacar el zip del lab sin abrir RDP de más.
4. **Task Scheduler 01:00 como SYSTEM** es el camino más simple en 2012 R2 (más estable que un servicio .NET custom para el MVP).
5. Cualquier integración Drive/OAuth debe vivir **fuera** del repo (token local, nunca commit).

---

## 7. Checklist de captura (operador)

1. Ejecutar `tools\Find-VoipSwitchConfigs.ps1`
2. Ejecutar `PortalVoIPBackupAgent.exe diagnose` y confirmar `pass_len > 0`
3. Ejecutar `backup` y verificar tamaño del zip
4. Copiar el zip a almacenamiento cifrado / offsite
5. Probar restore en un lab aislado antes de confiar en el job diario

---

## 8. Relación con el agente

Este análisis alimentó el diseño de **[PortalVoIPBackupAgent](../README.md)**:

- Auto-discovery → `internal/discover`
- Dump + zip → `internal/backup`
- Agenda 01:00 → `install` (schtasks)

Roadmap (Drive upload-only, AES, VSS, retención) sigue siendo la capa siguiente; la captura local ya es accionable.

---

## 9. Aviso legal / ética

Usar solo en sistemas **propios o autorizados**. Los dumps contienen CDR, tarifas y datos de abonados: trátelos como secreto industrial.