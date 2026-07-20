# loci-infra

Infrastructure-as-code for deploying Loci on a single **k3s** node at
**Hetzner**, fronted by **Cloudflare**, with **ArgoCD** GitOps.

```
Cloudflare (DNS + proxy + TLS edge)
        │  Full (strict), Origin Certificate
        ▼
Hetzner CPX31 ── k3s (Traefik ingress, local-path storage)
        ├── loci-api        (Deployment, Connect RPC + MCP, :8080 h2c)
        ├── loci-postgres   (StatefulSet: PostGIS + pgvector + TimescaleDB)
        │      └── nightly pg_dump → Hetzner Object Storage
        ├── sealed-secrets  (git-safe encrypted secrets)
        ├── argocd          (app-of-apps GitOps)
        └── alloy           → Grafana Cloud (metrics + logs)
```

The **web app stays on Cloudflare Workers** (deployed via wrangler from
`loci-client`); this repo only runs the API/DB/ops.

## Layout

| Path | What |
|---|---|
| `terraform/` | Hetzner node + firewall + cloud-init k3s + Cloudflare DNS. State in Hetzner S3. |
| `charts/loci-postgres/` | Postgres StatefulSet + backup CronJob. |
| `charts/loci-api/` | API Deployment + Service + Traefik IngressRoute. |
| `argocd/` | ArgoCD install values + root app-of-apps + child apps. |
| `observability/` | Grafana Alloy values (→ Grafana Cloud). |
| `secrets/` | Your committed SealedSecrets (see `secrets/README.md`). |
| `scripts/` | `seal-secret.sh` helper. |

## Prerequisites

- Tools: `terraform` ≥ 1.6, `kubectl`, `helm`, `kubeseal`.
- Accounts: Hetzner Cloud (API token + Object Storage bucket & S3 creds),
  Cloudflare (API token + Zone ID + Origin Certificate), Grafana Cloud (free).
- A domain on Cloudflare. Replace the `example.com` placeholders (in
  `terraform/terraform.tfvars`, `charts/loci-api/values.yaml`,
  `argocd/install-values.yaml`, `argocd/argocd-ingressroute.yaml`).

## Runbook

**1. Provision the node + DNS**
```sh
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in
export AWS_ACCESS_KEY_ID=<hetzner-s3-key> AWS_SECRET_ACCESS_KEY=<hetzner-s3-secret>
terraform init      # uses the Hetzner S3 backend
terraform apply
```

**2. Get the kubeconfig** (see the `kubeconfig_hint` output)
```sh
ssh root@$(terraform output -raw node_ipv4) 'cat /etc/rancher/k3s/k3s.yaml' \
  | sed "s#127.0.0.1#$(terraform output -raw node_ipv4)#" > ../kubeconfig.yaml
export KUBECONFIG=$PWD/../kubeconfig.yaml
kubectl get nodes    # Ready
```

**3. Install ArgoCD**
```sh
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
kubectl create namespace argocd
helm install argocd argo/argo-cd -n argocd -f ../argocd/install-values.yaml
kubectl apply -f ../argocd/argocd-ingressroute.yaml
```

**4. Seal your secrets** — see `secrets/README.md`, commit them, push this repo.
The ArgoCD apps pull this repo over SSH (`git@github.com:FACorreiaa/loci-infra.git`),
so give ArgoCD a **read-only deploy key**:
```sh
ssh-keygen -t ed25519 -f argocd_deploy -N ""      # add argocd_deploy.pub as a repo Deploy key on GitHub
argocd repo add git@github.com:FACorreiaa/loci-infra.git --ssh-private-key-path argocd_deploy
```
(Prefer HTTPS + PAT? Swap the `repoURL`s back to `https://github.com/...` and
`argocd repo add ... --username x --password <PAT>`.)

**5. Bootstrap the app-of-apps**
```sh
kubectl apply -f ../argocd/root-app.yaml
```
ArgoCD now syncs sealed-secrets → loci-secrets → loci-postgres → loci-api →
observability.

**6. Verify**
```sh
curl https://api.<your-domain>/health      # ok
kubectl -n loci get pods                    # loci-api + loci-postgres Running
```

## Continuous delivery (image bumps)

The **server repo's CI** builds and pushes `ghcr.io/facorreia/loci-connect-api`,
then commits the new tag into `charts/loci-api/values.yaml` here (repo-scoped
PAT). ArgoCD detects the git change and rolls the Deployment — auditable, no
image-updater component. Example step to add to the server's release workflow:

```yaml
- name: Bump loci-infra image tag
  run: |
    git clone https://x-access-token:${{ secrets.INFRA_PAT }}@github.com/FACorreiaa/loci-infra.git
    cd loci-infra
    yq -i '.image.tag = "${{ github.sha }}"' charts/loci-api/values.yaml
    git commit -am "deploy: loci-api ${{ github.sha }}" && git push
```

## Cutover from the old VPS

1. `pg_dump` the current VPS database.
2. Restore into the new cluster: `kubectl -n loci exec -i loci-postgres-0 -- psql ... < dump.sql`.
3. Brief write freeze, flip the real app/API DNS, watch error rates.
4. Keep the old VPS warm ~1 week for rollback.

## Non-negotiables

- **Back up the sealed-secrets private key** the moment the controller starts
  (see `secrets/README.md`). Losing it = re-seal everything.
- The Postgres image is **amd64-only** — keep `server_type` on an x86 plan.
- Verify a **backup restore** works before trusting the nightly CronJob.

## Restore drill (Postgres → GetTrip)

Run this before trusting prod backups. Goal: prove a dump can boot a usable API.

1. **Take a known-good dump** (or download the latest from the backup bucket):
   ```bash
   kubectl -n loci create job --from=cronjob/loci-postgres-backup restore-drill-backup
   # or: aws --endpoint-url … s3 cp s3://loci-db-backups/loci-<ts>.sql.gz .
   ```
2. **Restore into a scratch DB** (same cluster or a throwaway StatefulSet):
   ```bash
   gunzip -c loci-<ts>.sql.gz | \
     kubectl -n loci exec -i loci-postgres-0 -- \
       psql -U loci -d loci
   ```
3. **Smoke the API** against that DB (port-forward if needed):
   ```bash
   # Authenticate as a user who had a trip in the dump, then:
   # Connect RPC GetTrip / ListTrips — expect 200 + matching trip_id.
   curl -sS -H "Authorization: Bearer $TOKEN" \
     "$API_BASE/loci.trip.v1.TripService/ListTrips" \
     -H 'Content-Type: application/json' -d '{}'
   ```
4. **Pass criteria**: ListTrips/GetTrip return the pre-backup trip; no migration panic on API boot.
5. **Record** date + dump filename in the ops log; alert if `loci-postgres-backup` CronJob `lastScheduleTime` stalls >36h (wire PrometheusRule / Grafana alert next).

## Staging + Stripe test keys

- Point `charts/loci-api/values.yaml` `host` / `BASE_URL` / `ALLOWED_ORIGINS` at the staging domain (not production).
- SealedSecret `loci-api-secrets` must carry Stripe **test** keys (`sk_test_…`, `pk_test_…`, test price IDs) on staging; never seal live keys into a shared staging namespace.
- Preference re-rank CronJob (`loci-preference-rerank`, 03:15 UTC) shares the API image + DB config — disable via `preferenceRerank.enabled: false` if staging should stay cold.
