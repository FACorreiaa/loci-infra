# Cloudflare DNS. All records are proxied (orange cloud): Cloudflare
# terminates TLS with the edge cert and re-encrypts to the origin using the
# Origin Certificate installed in the cluster (SSL mode: Full (strict)).
#
# These are "stub" records pointing at the node — real traffic can be cut
# over by flipping them once the cluster is verified.

# NOTE: the apex/web app is served by the Cloudflare Worker (deployed via
# wrangler), which owns the root record and route — it is intentionally NOT
# managed here. Terraform only points the API and ArgoCD hostnames at the
# k3s node.

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = local.api_host
  type    = "A"
  content = hcloud_server.node.ipv4_address
  proxied = true
  ttl     = 1
  comment = "loci API + MCP endpoint (managed by terraform)"
}

resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = local.argocd_host
  type    = "A"
  content = hcloud_server.node.ipv4_address
  proxied = true
  ttl     = 1
  comment = "argocd UI (managed by terraform)"
}
