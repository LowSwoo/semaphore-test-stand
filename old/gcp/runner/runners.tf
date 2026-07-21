variable "runners" {
  description = "Runners to create, keyed by an arbitrary id. Each runs in its own region/zone; one subnet + Cloud NAT is provisioned per distinct region."
  type = map(object({
    name   = string
    region = string
    zone   = string
  }))
}

# Declare each runner in Semaphore. Its ID is used below to mint a one-time
# registration token the instance redeems during provisioning.
resource "semaphoreui_runner" "runner" {
  for_each           = var.runners
  name               = "${var.prefix}-${each.value.name}"
  max_parallel_tasks = 1
  active             = true
  tags               = ["local", "dev"]
}

# Rendered provisioning script per runner. Single source of truth so the
# replacement-trigger hash and the env var it ships can't drift.
locals {
  provision_scripts = {
    for k, v in var.runners : k => templatefile("${path.module}/provision.sh.tftpl", {
      semaphore_version = var.semaphore_version
      # runner-config.json and the systemd unit come from the shared templates.
      runner_config = templatefile("${path.module}/../../shared/runner/runner-config.json.tftpl", {
        web_root    = var.web_root
        runner_name = "${var.prefix}-${v.name}"
        tags        = ["local", "dev"]
      })
      runner_service = file("${path.module}/../../shared/runner/semaphore-runner.service")
    })
  }
}

# Drives recreation of the runner VM. Its id changes (forcing a replace) whenever
# the provisioning script or the Semaphore runner registration changes — see
# google_compute_instance.runner's replace_triggered_by below. A change to either
# means the box must be reprovisioned from scratch, not just re-run in place.
resource "terraform_data" "runner_replacement" {
  for_each = var.runners

  triggers_replace = {
    script_hash = sha256(local.provision_scripts[each.key])
    runner_id   = semaphoreui_runner.runner[each.key].id
  }
}

resource "google_compute_instance" "runner" {
  for_each = var.runners

  name         = "${var.prefix}-${each.value.name}"
  machine_type = var.machine_type
  zone         = "${each.value.region}-${each.value.zone}"
  tags         = [local.tag_runner]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.runners[each.value.region].id
    # No external IP — outbound via this VPC's regional Cloud NAT (org policy
    # forbids external IPs).
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${local.ssh_public_key}"
  }

  # Rebuild the VM when the provisioning script or runner registration changes.
  lifecycle {
    replace_triggered_by = [terraform_data.runner_replacement[each.key]]
  }
}

# The instances have no public IP (org policy), so Terraform cannot SSH to them
# directly. Provisioning therefore runs locally via `gcloud ... --tunnel-through-iap`,
# which reaches the private instance over Google's Identity-Aware Proxy. This
# requires the gcloud CLI to be authenticated (`gcloud auth login`) and the
# caller to hold roles/iap.tunnelResourceAccessor on the project.
resource "terraform_data" "provision" {
  for_each = var.runners

  # Follow the instance: provisioning re-runs whenever the VM is (re)created.
  # Script and runner-id changes already force a VM rebuild via the instance's
  # replace_triggered_by, so tracking the instance id alone is sufficient here.
  triggers_replace = [
    google_compute_instance.runner[each.key].id,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      PROJECT  = var.gcp_project
      ZONE     = "${each.value.region}-${each.value.zone}"
      INSTANCE = google_compute_instance.runner[each.key].name
      # The provisioning script carries NO secrets, so it is safe to land on the
      # instance disk. Passed as a single env var to avoid heredoc pitfalls.
      PROVISION_SCRIPT = local.provision_scripts[each.key]
      # API token and registration inputs stay on the Terraform host — never
      # written into the script that is copied to the instance.
      API_TOKEN    = local.api_token
      API_BASE_URL = local.api_base_url
      RUNNER_ID    = semaphoreui_runner.runner[each.key].id
    }

    command = <<-EOT
      set -euo pipefail
      TMP=$(mktemp -d)
      printf '%s' "$PROVISION_SCRIPT" > "$TMP/provision.sh"

      # IAP tunnels to a freshly-booted VM are flaky (sshd not up yet, transient
      # "failed to connect to backend" on port 22). Retry every gcloud call so a
      # momentary hiccup doesn't fail the whole apply. stdin is passed via a file
      # so the command can be retried without consuming a pipe.
      retry() {
        local n=0 max=30
        until "$@"; do
          n=$((n + 1))
          if [ "$n" -ge "$max" ]; then
            echo "command failed after $max attempts: $*" >&2
            return 1
          fi
          echo "attempt $n/$max failed, retrying in 10s ..." >&2
          sleep 10
        done
      }

      echo "Waiting for SSH (IAP) on $INSTANCE ..."
      retry gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
        --tunnel-through-iap --quiet --command "true"

      # Ship the (secret-free) script over IAP and run it with sudo.
      retry gcloud compute scp "$TMP/provision.sh" "$INSTANCE":/tmp/provision.sh \
        --zone "$ZONE" --project "$PROJECT" --tunnel-through-iap --quiet

      retry gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
        --tunnel-through-iap --quiet --command "sudo bash /tmp/provision.sh"

      # Exchange the API token for a one-time runner registration token locally,
      # so the API token never leaves this host. Pipe the short-lived token to the
      # instance over SSH stdin and register; nothing is written to a file there.
      # The registration token is single-use, so mint a fresh one on every attempt
      # — otherwise a retry after a dropped connection would reuse a spent token.
      register_runner() {
        local token
        token=$(curl -XPOST -sf \
          -H "Authorization: Bearer $API_TOKEN" \
          -H 'content-type: application/json' \
          "$API_BASE_URL/runners/$RUNNER_ID/registration-token" \
          | jq -r .registration_token)
        if [ -z "$token" ] || [ "$token" = "null" ]; then
          echo "failed to obtain registration token" >&2
          return 1
        fi
        printf '%s' "$token" | gcloud compute ssh "$INSTANCE" \
          --zone "$ZONE" --project "$PROJECT" --tunnel-through-iap --quiet \
          --command "sudo /usr/local/bin/semaphore runner register --stdin-registration-token --config /etc/semaphore/runner-config.json"
      }
      retry register_runner

      retry gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
        --tunnel-through-iap --quiet --command "sudo systemctl enable --now semaphore-runner"
    EOT
  }
}
