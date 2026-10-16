# Recorrido 3D de tramites-platform

Una visita guiada en 3D por toda la plataforma: de la laptop del desarrollador hasta el ciudadano,
pasando por las barreras de secretos, la protección de `main`, el CI, la autenticación sin llaves,
el registro de imágenes, la firma con KMS, Binary Authorization (con el rechazo de una imagen sin
firmar), Cloud Run, Secret Manager, el mínimo privilegio, Terraform y los costos.

Cada una de las 15 estaciones explica qué se ve, **por qué se diseñó así**, en qué archivos del
repositorio está, un comando para comprobarlo y una pregunta corta para ver si quedó claro.

## Cómo abrirlo

Basta con abrir `index.html` en el navegador (necesita conexión para descargar three.js). Si el
navegador bloquea algo al abrir el archivo directamente, sírvelo en local:

```bash
python3 -m http.server 8000 --directory 3dtour
# http://localhost:8000
```

## Controles

| Acción | Cómo |
|---|---|
| Siguiente / anterior | Botones `▶` `◀` o las flechas `→` `←` |
| Reproducción automática | Botón `⏵` o la barra espaciadora |
| Girar y acercar la cámara | Arrastrar con el ratón y rueda (`⟲` o `R` la restablece) |
| Ocultar el panel (para presentar) | Botón `▤` o `H` |
| Ir a una estación | Los puntos de la barra inferior, o `#/N` en la URL (por ejemplo `#/9`) |

## Cómo está hecho

- Un solo archivo, [index.html](index.html), sin dependencias que instalar.
- three.js `0.184.0` se carga desde el CDN fijado a **esa versión exacta** y con **verificación de
  integridad** (SRI): si el archivo del CDN cambiara, el navegador se niega a ejecutarlo. Es la
  misma idea que fijar las acciones de GitHub por SHA.
- Si no hay conexión o WebGL, la página muestra el mismo contenido como texto.
- Respeta `prefers-reduced-motion` (sin movimientos de cámara animados) y funciona en pantallas
  estrechas.
- No contiene secretos ni identificadores de la cuenta: los comandos usan marcadores como
  `<project_id>`.

### Actualizar la versión de three.js

Cambia la versión en el `importmap` y recalcula los dos hashes (los archivos descargados son datos
no confiables: no los ejecutes, solo calcula su hash):

```bash
V=0.184.0
for f in three.module.min.js three.core.min.js; do
  curl -fsS "https://cdn.jsdelivr.net/npm/three@$V/build/$f" \
    | openssl dgst -sha384 -binary | openssl base64 -A | sed "s/^/$f sha384-/"; echo
done
```

## Mantenerlo al día

El contenido educativo está en la constante `STEPS` al inicio del script. Si cambia algo de la
plataforma (un rol, un nombre, un comando), actualiza también la estación correspondiente: está
pensado para explicar lo que realmente existe en este repositorio.
