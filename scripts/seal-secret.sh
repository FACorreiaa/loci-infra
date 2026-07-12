#!/usr/bin/env bash
# Seal a generic key/value Secret for the loci deployment.
#
# Usage:
#   scripts/seal-secret.sh <namespace> <secret-name> KEY=VALUE [KEY=VALUE ...]
#
# Example:
#   scripts/seal-secret.sh loci loci-api-secrets \
#     GEMINI_API_KEY=abc JWT_SECRET=xyz DB_PASSWORD=pw > secrets/loci-api-secrets.yaml
#
# Requires: kubectl, kubeseal, and a reachable cluster running the
# sealed-secrets controller.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <namespace> <secret-name> KEY=VALUE [KEY=VALUE ...]" >&2
  exit 1
fi

namespace="$1"
name="$2"
shift 2

args=()
for kv in "$@"; do
  args+=(--from-literal="$kv")
done

kubectl create secret generic "$name" \
  --namespace "$namespace" \
  "${args[@]}" \
  --dry-run=client -o yaml \
  | kubeseal --format yaml
