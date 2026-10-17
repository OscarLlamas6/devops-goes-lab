#!/usr/bin/env bash
# Demonstrates that Binary Authorization rejects an image the pipeline did not attest.
# It builds and pushes an UNSIGNED image, tries to deploy it by digest, and stores the denial in
# docs/evidencias/binauthz-rechazo.txt. It deliberately does NOT use --no-traffic or --tag: those
# pin the service traffic to one revision and leave a tag pointing at the rejected revision, which
# stops later pipeline deploys from receiving traffic.
# Run it with your own gcloud identity (not the pipeline's). Usage: ./scripts/demo-binauthz-reject.sh
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-tramites-api}"
REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/tramites"
TAG="unsigned-$(date +%Y%m%d%H%M%S)"
IMAGE="${REPO}/${SERVICE_NAME}:${TAG}"
EVIDENCE="docs/evidencias/binauthz-rechazo.txt"

if [ -z "$PROJECT_ID" ]; then
  echo "Set PROJECT_ID or run: gcloud config set project <id>" >&2
  exit 1
fi
if [ ! -f app/Dockerfile ]; then
  echo "Run this script from the repository root." >&2
  exit 1
fi

mkdir -p docs/evidencias
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet >/dev/null

echo "==> Building and pushing an UNSIGNED image: ${IMAGE}"
docker build --quiet --build-arg APP_VERSION="${TAG}" -t "${IMAGE}" app >/dev/null
docker push --quiet "${IMAGE}" >/dev/null
DIGEST="$(gcloud artifacts docker images describe "${IMAGE}" --format='value(image_summary.digest)')"

{
  echo "# Binary Authorization rejection demo"
  echo "# date:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# project: ${PROJECT_ID}"
  echo "# image:   ${REPO}/${SERVICE_NAME}@${DIGEST} (no attestation)"
  echo "# command: gcloud run deploy ${SERVICE_NAME} --image <image>@<digest>"
  echo
} > "${EVIDENCE}"

echo "==> Trying to deploy it (this MUST be rejected)"
set +e
export CLOUDSDK_CORE_DISABLE_COLOR=true # keep the evidence file free of ANSI escape codes
gcloud run deploy "${SERVICE_NAME}" \
  --image "${REPO}/${SERVICE_NAME}@${DIGEST}" \
  --region "${REGION}" \
  --quiet >> "${EVIDENCE}" 2>&1
STATUS=$?
set -e

cat "${EVIDENCE}"
echo

if [ "${STATUS}" -eq 0 ]; then
  echo "❌ UNEXPECTED: the unsigned image was ACCEPTED. Binary Authorization is not enforcing." >&2
  echo "   A revision tagged 'unsigned' now exists on ${SERVICE_NAME}; remove it before continuing." >&2
  exit 1
fi

echo "✅ Rejected as expected (exit ${STATUS}). Evidence saved to ${EVIDENCE}"
echo
# The denial is not logged by binaryauthorization.googleapis.com (that one only records changes to
# the policy and attestors). It shows up as an ERROR audit event of the Cloud Run service itself.
LOG_FILTER="protoPayload.status.message:\"denied by attestor\" AND protoPayload.status.message:\"${DIGEST}\""
echo "==> Looking for the denial in Cloud Logging (audit entries can take a few seconds)"
LOG_ENTRY=""
for _ in 1 2 3 4 5 6; do
  LOG_ENTRY="$(gcloud logging read "${LOG_FILTER}" --limit 1 --freshness 1h \
    --format='value(timestamp,severity,logName.basename(),protoPayload.methodName,protoPayload.status.code)' 2>/dev/null || true)"
  [ -n "${LOG_ENTRY}" ] && break
  sleep 5
done
if [ -n "${LOG_ENTRY}" ]; then
  {
    echo
    echo "# Cloud Logging entry (timestamp, severity, log, method, status code 7 = PERMISSION_DENIED)"
    echo "# filter: ${LOG_FILTER}"
    echo "${LOG_ENTRY}"
  } >> "${EVIDENCE}"
  echo "${LOG_ENTRY}"
else
  echo "Not found yet. Look for it manually in the console."
fi
echo
echo "To take the screenshot: Console -> Logging -> Logs Explorer, query:"
echo "    ${LOG_FILTER}"

echo
echo "==> Traffic after the attempt (it must still follow the latest ready revision):"
gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --format='yaml(spec.traffic)' || true
echo "    Expected: a single entry with 'latestRevision: true'. If it lists a revision name or a tag,"
echo "    later deploys will NOT receive traffic. Fix it with:"
echo "      gcloud run services update-traffic ${SERVICE_NAME} --region ${REGION} --remove-tags=unsigned"
echo "      gcloud run services update-traffic ${SERVICE_NAME} --region ${REGION} --to-latest"

echo
echo "==> The unsigned test image is left in Artifact Registry. Remove it with:"
echo "    gcloud artifacts docker images delete ${REPO}/${SERVICE_NAME}@${DIGEST} --delete-tags"
