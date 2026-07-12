variable "hcloud_token" {
  description = "Hetzner Cloud API token (project-scoped, read/write)."
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit for the zone below."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for var.domain."
  type        = string
}

variable "domain" {
  description = "Apex domain the app is served on. PLACEHOLDER — set to your real domain."
  type        = string
  default     = "example.com"
}

variable "ssh_public_key" {
  description = "SSH public key granted access to the node (contents, not a path)."
  type        = string
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH (22) and the k8s API (6443). Lock to your IP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "server_type" {
  description = "Hetzner server type. cpx31 = 4 vCPU (AMD) / 8 GB. Must be x86 — the Postgres image is amd64-only."
  type        = string
  default     = "cpx31"
}

variable "location" {
  description = "Hetzner location. fsn1/nbg1/hel1 (EU), ash/hil (US)."
  type        = string
  default     = "fsn1"
}

variable "server_image" {
  description = "Base OS image for the node."
  type        = string
  default     = "ubuntu-24.04"
}

variable "name_prefix" {
  description = "Prefix for created Hetzner resources."
  type        = string
  default     = "loci"
}
