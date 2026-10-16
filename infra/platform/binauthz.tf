# Binary Authorization: Cloud Run only starts images that carry an attestation signed by the
# pipeline. Everything here is created only when enable_binauthz = true.

locals {
  binauthz_count = var.enable_binauthz ? 1 : 0
}

# Asymmetric signing key. The private half never leaves Cloud KMS.
# WARNING: key rings cannot be deleted in GCP and key versions are only scheduled for
# destruction, so `terraform destroy` leaves a (nearly free) key ring behind. See README.
resource "google_kms_key_ring" "attestor" {
  count = local.binauthz_count

  name     = "tramites-attestor"
  location = var.region
}

resource "google_kms_crypto_key" "attestor" {
  count = local.binauthz_count

  name     = "pipeline-signer"
  key_ring = google_kms_key_ring.attestor[0].id
  purpose  = "ASYMMETRIC_SIGN"
  labels   = local.labels

  version_template {
    algorithm = "EC_SIGN_P256_SHA256"
  }
}

data "google_kms_crypto_key_version" "attestor" {
  count = local.binauthz_count

  crypto_key = google_kms_crypto_key.attestor[0].id
}

# Container Analysis note: the anchor that attestations (occurrences) hang from.
resource "google_container_analysis_note" "attestor" {
  count = local.binauthz_count

  name = "attestor-pipeline-note"

  attestation_authority {
    hint {
      human_readable_name = "Attestor of the tramites pipeline"
    }
  }
}

resource "google_binary_authorization_attestor" "pipeline" {
  count = local.binauthz_count

  name = "pipeline-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor[0].name

    public_keys {
      id = data.google_kms_crypto_key_version.attestor[0].id

      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor[0].public_key[0].pem
        signature_algorithm = "ECDSA_P256_SHA256"
      }
    }
  }
}

# No allowlist for the placeholder image on purpose: a permanent exception is a permanent hole.
resource "google_binary_authorization_policy" "this" {
  count = local.binauthz_count

  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.pipeline[0].name]
  }
}

# --- sa-deployer permissions to sign and record attestations ---

resource "google_kms_crypto_key_iam_member" "deployer_signs" {
  count = local.binauthz_count

  crypto_key_id = google_kms_crypto_key.attestor[0].id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_container_analysis_note_iam_member" "deployer_attaches" {
  count = local.binauthz_count

  note   = google_container_analysis_note.attestor[0].name
  role   = "roles/containeranalysis.notes.attacher"
  member = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_binary_authorization_attestor_iam_member" "deployer_views_attestor" {
  count = local.binauthz_count

  attestor = google_binary_authorization_attestor.pipeline[0].name
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# Occurrences (the attestations themselves) have no resource-level IAM in Container Analysis,
# so this is the one grant that has to be at project level. It only allows creating and editing
# occurrences; it cannot read secrets, change infrastructure or deploy.
resource "google_project_iam_member" "deployer_writes_attestations" {
  count = local.binauthz_count

  project = var.project_id
  role    = "roles/containeranalysis.occurrences.editor"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}
