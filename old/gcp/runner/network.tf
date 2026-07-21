# Dedicated VPC for the runners, separate from the server stack's VPC.
#
# Why a separate network: the runners must reach the Semaphore server through its
# *external* load-balancer IP. When a private (no-external-IP) VM sends traffic to
# the external IP of a load balancer in the SAME VPC, Cloud NAT does not translate
# it — Google routes it internally and the TCP handshake hangs intermittently. By
# placing runners in their own VPC, that LB IP is genuinely off-network, so Cloud
# NAT egresses to it over the internet like any other public address.
resource "google_compute_network" "runners" {
  name                    = "${var.prefix}-runner-vpc"
  auto_create_subnetworks = false
}

locals {
  # Distinct regions the runners live in; each gets its own subnet + Cloud NAT.
  runner_regions = sort(distinct([for r in var.runners : r.region]))

  # Deterministic, non-overlapping /24 per region, carved from var.runner_cidr.
  # sort() keeps the index (and thus each region's CIDR) stable across plans.
  runner_subnets = {
    for idx, region in local.runner_regions :
    region => cidrsubnet(var.runner_cidr, 8, idx)
  }
}

resource "google_compute_subnetwork" "runners" {
  for_each = local.runner_subnets

  name          = "${var.prefix}-runner-${each.key}"
  region        = each.key
  network       = google_compute_network.runners.id
  ip_cidr_range = each.value
}

# Cloud NAT is regional, so one router + NAT per region the runners occupy. This
# gives the private runners outbound internet for apt, GitHub release downloads,
# and reaching the Semaphore server over its public load balancer.
resource "google_compute_router" "runners" {
  for_each = google_compute_subnetwork.runners

  name    = "${var.prefix}-runner-router-${each.key}"
  region  = each.key
  network = google_compute_network.runners.id
}

resource "google_compute_router_nat" "runners" {
  for_each = google_compute_router.runners

  name                               = "${var.prefix}-runner-nat-${each.key}"
  router                             = each.value.name
  region                             = each.key
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
