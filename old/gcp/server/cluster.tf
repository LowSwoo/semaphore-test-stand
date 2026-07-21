# Semaphore UI instances behind the load balancer. They share one zone/subnet.
# Private IPs of Postgres and Redis are resolved from their instance resources
# (created first).
resource "terraform_data" "cluster_replace_on_semaphore_version" {
  input = var.semaphore_version
}

resource "google_compute_instance" "cluster" {
  count        = 1
  name         = "${var.prefix}-ui-${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = [local.tag_base, local.tag_ui]

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
    user-data = templatefile("${path.module}/../../shared/cloud-init/semaphore-systemd.yaml.tftpl", {
      # Create the admin user in cloud-init on the first node so admin-token.tf
      # can mint an API token from it deterministically (rather than racing the
      # server's env-based admin creation on startup).
      bootstrap             = count.index == 0
      db_host               = google_compute_instance.postgres.network_interface[0].network_ip
      db_name               = var.db_name
      db_user               = var.db_user
      db_password           = var.db_password
      redis_host            = google_compute_instance.redis.network_interface[0].network_ip
      redis_password        = var.redis_password
      web_root              = "https://${local.lb_fqdn}"
      cookie_hash           = var.semaphore_cookie_hash
      cookie_encryption     = var.semaphore_cookie_encryption
      access_key_encryption = var.semaphore_access_key_encryption
      admin_user            = var.semaphore_admin_user
      admin_password        = var.semaphore_admin_password
      admin_email           = var.semaphore_admin_email
      semaphore_version     = var.semaphore_version
      node_index            = count.index + 1
    })
  }

  lifecycle {
    replace_triggered_by = [terraform_data.cluster_replace_on_semaphore_version]
  }
}
