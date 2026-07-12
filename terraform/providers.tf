provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  app_host    = var.domain             # web app / apex
  api_host    = "api.${var.domain}"    # Connect RPC + MCP endpoint
  argocd_host = "argocd.${var.domain}" # ArgoCD UI
}
