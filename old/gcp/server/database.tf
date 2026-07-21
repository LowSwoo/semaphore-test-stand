locals {
  # GCP metadata server endpoint for the instance's own private IP. Injected into
  # the shared postgres/redis cloud-init templates (DO uses a different endpoint).
  metadata_private_ip_cmd = "curl -s -H \"Metadata-Flavor: Google\" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip"
}

resource "google_compute_instance" "postgres" {
  name         = "${var.prefix}-postgres"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.tag_base, local.tag_database]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # No external IP — outbound via Cloud NAT (org policy forbids external IPs).
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
    user-data = templatefile("${path.module}/../../shared/cloud-init/postgres.yaml.tftpl", {
      db_name        = var.db_name
      db_user        = var.db_user
      db_password    = var.db_password
      vpc_ip_range   = var.subnet_ip_range
      private_ip_cmd = local.metadata_private_ip_cmd
    })
  }
}

resource "google_compute_instance" "redis" {
  name         = "${var.prefix}-redis"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.tag_base, local.tag_redis]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # No external IP — outbound via Cloud NAT (org policy forbids external IPs).
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
    user-data = templatefile("${path.module}/../../shared/cloud-init/redis.yaml.tftpl", {
      redis_password = var.redis_password
      private_ip_cmd = local.metadata_private_ip_cmd
    })
  }
}
