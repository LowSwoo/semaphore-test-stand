# Mint the admin API token over SSH and capture it on the machine running
# Terraform. GCP cluster nodes have no public IP (org policy), so we reach the
# bootstrap node through Identity-Aware Proxy — the same transport the runner
# stack uses. The token is generated on demand and never written to the server's
# disk; only its stdout is captured into a local file.
#
# cloud-init runs asynchronously and creates the admin user during runcmd (the
# bootstrap step on cluster[0]), so we wait for it to finish before minting.
resource "terraform_data" "fetch_admin_token" {
  # Re-mint whenever the bootstrap node is (re)created.
  triggers_replace = [google_compute_instance.cluster[0].id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      PROJECT    = var.gcp_project
      ZONE       = var.zone
      INSTANCE   = google_compute_instance.cluster[0].name
      ADMIN_USER = var.semaphore_admin_user
      DEST       = "${local.api_token_path}"
    }

    command = <<-EOT
      set -euo pipefail

      # IAP tunnels to a freshly-booted VM are flaky (sshd not up yet, transient
      # "failed to connect to backend" on port 22). Retry every gcloud call so a
      # momentary hiccup doesn't fail the whole apply.
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

      echo "Waiting for cloud-init on $INSTANCE ..."
      retry gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
        --tunnel-through-iap --quiet --command "cloud-init status --wait"

      # Generate the token on the server and capture its stdout. Captured into a
      # variable (not redirected through retry) so a retried attempt can't append
      # partial output to the file. NOTE: verify the user selector flag for your
      # Semaphore version (`semaphore user token create --help` — --login/--user-id).
      mint_token() {
        gcloud compute ssh "$INSTANCE" --zone "$ZONE" --project "$PROJECT" \
          --tunnel-through-iap --quiet \
          --command "sudo /usr/local/bin/semaphore user token create --config /etc/semaphore/config.yml --login '$ADMIN_USER'"
      }
      TOKEN=$(retry mint_token)
      if [ -z "$TOKEN" ]; then
        echo "minted token is empty" >&2
        exit 1
      fi
      printf '%s' "$TOKEN" > "$DEST"
      echo "Saved admin token to $DEST"
    EOT
  }
}
