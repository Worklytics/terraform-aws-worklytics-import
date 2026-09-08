#!/usr/bin/env bash
# Prove the Worklytics GCP identity can read and write objects in the import bucket
# via Google → AWS AssumeRoleWithWebIdentity.
#
# Usage:
#   ./test/s3_roundtrip.sh \
#     <tenant_sa_email> \
#     <bucket_name> \
#     <iam_role_arn> \
#     [<id_token_audience>]
#
# Prerequisites:
#   - gcloud authenticated as an identity that can impersonate tenant_sa_email
#   - aws CLI
set -euo pipefail

TENANT_SA_EMAIL="${1:?tenant SA email required}"
BUCKET_NAME="${2:?bucket name required}"
IAM_ROLE_ARN="${3:?IAM role ARN required}"
# IAM trust policy keys on accounts.google.com:aud and :sub = tenant SA unique ID.
ID_TOKEN_AUDIENCE="${4:-${ID_TOKEN_AUDIENCE:-}}"

CI_RUN="${CI_RUN:-$(date +%Y%m%dT%H%M%S)}"
OBJECT_KEY="ci/${CI_RUN}/test.txt"
OBJECT_BODY="worklytics-import-ci ${CI_RUN}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

echo "TENANT_SA_EMAIL: ${TENANT_SA_EMAIL}"
echo "BUCKET_NAME: ${BUCKET_NAME}"
echo "IAM_ROLE_ARN: ${IAM_ROLE_ARN}"
echo "ID_TOKEN_AUDIENCE: ${ID_TOKEN_AUDIENCE:-"(gcloud default)"}"
echo "OBJECT: s3://${BUCKET_NAME}/${OBJECT_KEY}"

TOKEN_ARGS=(--impersonate-service-account="${TENANT_SA_EMAIL}")
if [[ -n "${ID_TOKEN_AUDIENCE}" ]]; then
  TOKEN_ARGS+=(--audiences="${ID_TOKEN_AUDIENCE}")
fi
GCP_TOKEN="$(gcloud auth print-identity-token "${TOKEN_ARGS[@]}")"

assume_role() {
  aws sts assume-role-with-web-identity \
    --role-arn "${IAM_ROLE_ARN}" \
    --role-session-name "ci-run-${CI_RUN}" \
    --web-identity-token "${GCP_TOKEN}" \
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
    --output text
}

retry() {
  local attempt=1
  local max_attempts=12
  local delay=10
  local output
  while (( attempt <= max_attempts )); do
    if output="$("$@" 2>&1)"; then
      printf '%s' "${output}"
      return 0
    fi
    echo "Attempt ${attempt}/${max_attempts} failed: ${output}" >&2
    sleep "${delay}"
    delay=$(( delay < 40 ? delay * 2 : 40 ))
    attempt=$(( attempt + 1 ))
  done
  echo "Giving up after ${max_attempts} attempts." >&2
  return 1
}

echo "Assuming import role with Google ID token..."
CREDS="$(retry assume_role)"
# shellcheck disable=SC2086
export $(printf "AWS_ACCESS_KEY_ID=%s AWS_SECRET_ACCESS_KEY=%s AWS_SESSION_TOKEN=%s" ${CREDS})

printf '%s' "${OBJECT_BODY}" > "${WORKDIR}/test.txt"

put_object() {
  aws s3 cp "${WORKDIR}/test.txt" "s3://${BUCKET_NAME}/${OBJECT_KEY}"
}

get_object() {
  aws s3 cp "s3://${BUCKET_NAME}/${OBJECT_KEY}" "${WORKDIR}/downloaded.txt"
}

echo "Writing object as federated GCP identity..."
retry put_object

echo "Reading object as federated GCP identity..."
retry get_object

DOWNLOADED="$(cat "${WORKDIR}/downloaded.txt")"
if [[ "${DOWNLOADED}" != "${OBJECT_BODY}" ]]; then
  echo "Object content mismatch." >&2
  echo "expected: ${OBJECT_BODY}" >&2
  echo "actual:   ${DOWNLOADED}" >&2
  exit 1
fi

echo "Read/write round-trip succeeded."
