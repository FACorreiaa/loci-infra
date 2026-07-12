# Secrets (SealedSecrets)

Real secrets never live in git as plaintext. You create **SealedSecrets**
here — encrypted with the in-cluster sealed-secrets controller's public key,
safe to commit. ArgoCD's `loci-secrets` app applies them; the controller
decrypts each into a normal `Secret` in the `loci` namespace.

## Required secrets

| Secret name | Keys | Used by |
|---|---|---|
| `ghcr-pull` | `.dockerconfigjson` (type `kubernetes.io/dockerconfigjson`) | pulling private GHCR images |
| `loci-postgres-credentials` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | postgres StatefulSet + backup |
| `loci-api-secrets` | `GEMINI_API_KEY`, `JWT_SECRET`, `DB_PASSWORD`, `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET`, `SMTP_PASSWORD`, `TWILIO_AUTH_TOKEN`, `SESSION_SECRET`, OAuth secrets | the API |
| `loci-origin-cert` | `tls.crt`, `tls.key` (type `kubernetes.io/tls`) — Cloudflare Origin Certificate | Traefik TLS |
| `loci-backup-s3` | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | nightly DB backup |
| `grafana-cloud` | `GC_PROM_URL`, `GC_PROM_USER`, `GC_LOKI_URL`, `GC_LOKI_USER`, `GC_API_KEY` | Alloy (observability namespace) |

> `DB_PASSWORD` in `loci-api-secrets` must equal `POSTGRES_PASSWORD` in
> `loci-postgres-credentials` (same database, two consumers).

## Create one

```sh
# generic key/value secret
../scripts/seal-secret.sh loci loci-api-secrets \
  GEMINI_API_KEY=... JWT_SECRET=... DB_PASSWORD=... > loci-api-secrets.yaml

# the GHCR pull secret
kubectl create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<gh-user> --docker-password=<gh-PAT> \
  --namespace loci --dry-run=client -o yaml \
  | kubeseal --format yaml > ghcr-pull.yaml

# the TLS origin cert
kubectl create secret tls loci-origin-cert \
  --cert=origin.pem --key=origin.key --namespace loci \
  --dry-run=client -o yaml | kubeseal --format yaml > loci-origin-cert.yaml
```

Commit the resulting `*.yaml` (they are encrypted). **Back up the controller's
private key immediately** — losing it means re-sealing every secret:

```sh
kubectl -n kube-system get secret \
  -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml \
  > sealed-secrets-key.backup.yaml   # store OUT of git, in a password manager
```
