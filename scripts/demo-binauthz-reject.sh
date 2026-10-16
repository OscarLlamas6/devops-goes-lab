#!/usr/bin/env bash
# Demonstrates that Binary Authorization rejects an image the pipeline did not attest.
# It builds and pushes an UNSIGNED image, tries to deploy it by digest as a revision without
# traffic, and stores the denial in docs/evidencias/binauthz-rechazo.txt.
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
  echo "# command: gcloud run deploy ${SERVICE_NAME} --image <image>@<digest> --no-traffic --tag=unsigned"
  echo
} > "${EVIDENCE}"

echo "==> Trying to deploy it (this MUST be rejected)"
set +e
gcloud run deploy "${SERVICE_NAME}" \
  --image "${REPO}/${SERVICE_NAME}@${DIGEST}" \
  --region "${REGION}" \
  --no-traffic --tag=unsigned --quiet >> "${EVIDENCE}" 2>&1
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
echo "Where to see the denial in Cloud Logging (take the screenshot there):"
echo "  Console -> Logging -> Logs Explorer, query:"
echo "    protoPayload.serviceName=\"binaryauthorization.googleapis.com\""
echo "  or from the CLI:"
echo "    gcloud logging read 'protoPayload.serviceName=\"binaryauthorization.googleapis.com\"' --limit 5 --freshness 1h"

echo
echo "==> The unsigned test image is left in Artifact Registry. Remove it with:"
echo "    gcloud artifacts docker images delete ${REPO}/${SERVICE_NAME}@${DIGEST} --delete-tags"
