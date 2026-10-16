# Criterio

## 1. En 10 líneas o menos, describe un Golden Path para este servicio: qué incluye, qué dejas fuera a propósito y cómo medirías si los equipos lo usan.
Incluye: una plantilla de repositorio por lenguaje (Go, Python, React) con Dockerfile multistage y
usuario no-root; workflows reutilizables de CI y de despliegue firmado por digest; un módulo de
Terraform `cloud-run-service` que ya trae su service account, el secreto en Secret Manager,
Binary Authorization, el máximo de instancias y las etiquetas de costo; y logs estructurados con un
dashboard por defecto. **Dejo fuera a propósito:** GKE/Kubernetes, pipelines a la medida de cada
equipo, service mesh y multi-cloud. Quien se salga del camino puede hacerlo, pero lo mantiene él.
**Cómo mediría que lo usan:** % de servicios creados desde la plantilla; tiempo hasta el primer
despliegue de un servicio nuevo; frecuencia de despliegue y *lead time* (DORA); tasa de fallos de
cambio; y tickets a DevOps por despliegue, que debería tender a cero.

## 2. El servicio tiene que consultar un sistema on-premise (SOAP) y un servicio en AWS. ¿Cómo conectas las tres partes de forma segura? Considera costo y riesgo


Cloud Run con *Direct VPC egress* hacia una VPC propia. **On-premise:** HA VPN con Cloud Router
(BGP). Descarto Interconnect por costo para este volumen, y exponer el SOAP a internet por riesgo.
Un adaptador (capa anticorrupción) traduce SOAP a REST con *timeouts*, *circuit breaker* y una
caché corta del estado del trámite, para no tumbar el legado en horas pico. **AWS:** primero
pregunto si hace falta red privada. Si no, llamada HTTPS con **federación de identidad GCP a AWS**
(token OIDC de la service account, `AssumeRoleWithWebIdentity`), sin llaves estáticas; si sí, HA VPN
entre ambas nubes. Salida por Cloud NAT con IP fija para las listas de permitidos, mTLS donde se
pueda, firewall de mínimo acceso y *flow logs*. **Costo:** HA VPN son unos USD 0.05 por túnel-hora
(dos túneles, ≈ USD 72 al mes) más el tráfico de salida. **Riesgo:** el legado es el cuello de
botella; por eso la caché y la degradación elegante.

## 3. ¿Qué controles pondrías para que un ambiente de desarrollo no gaste USD 2,000 en un fin de semana?

**(a) Topes duros:** cuotas del proyecto (GPU en cero), `max_instance_count` obligatorio en el
módulo y políticas de organización (regiones y tipos de máquina permitidos, sin IP externa).
**(b) Detección rápida:** presupuestos con alerta sobre el **pronóstico**, exportación de la
facturación a BigQuery y detección de anomalías. **(c) Reacción automática:** presupuesto a Pub/Sub
a una función que escala a cero o desvincula la facturación del proyecto de desarrollo (*kill
switch*: aceptable en desarrollo, no en producción). **(d) Higiene:** recursos solo por IaC,
etiquetas obligatorias de dueño y fecha de expiración, apagado programado de viernes a lunes y sin
endpoints públicos en desarrollo. **Descarté** depender solo de alertas: llegan con horas de retraso
y no detienen nada. Un ejemplo propio: el presupuesto de este laboratorio avisa, pero no corta.
