# Mint the admin API token over SSH and capture it on the machine running
# Terraform. The token is generated on demand and never written to the server's
# disk — only its stdout is redirected into a local file.
#
# cloud-init runs asynchronously and creates the admin user during runcmd, so we
# wait for it to finish before minting the token. No -i / key path is passed:
# ssh picks the key up from your ssh-agent (same as the droplet connection blocks).
resource "terraform_data" "fetch_admin_token" {
  # Re-mint whenever the bootstrap node is (re)created.
  triggers_replace = [digitalocean_droplet.cluster[0].id]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    environment = {
      IP         = digitalocean_droplet.cluster[0].ipv4_address
      ADMIN_USER = var.semaphore_admin_user
      DEST       = "${local.api_token_path}"
    }

    command = <<-EOT
      set -euo pipefail
      SSH_OPTS="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

      echo "Waiting for cloud-init on $IP ..."
      for i in $(seq 1 60); do
        if ssh $SSH_OPTS root@"$IP" 'cloud-init status --wait >/dev/null 2>&1'; then
          break
        fi
        if [ "$i" -eq 60 ]; then
          echo "cloud-init did not finish within timeout on $IP" >&2
          exit 1
        fi
        sleep 5
      done

      ssh $SSH_OPTS root@"$IP" \
        "semaphore user token create --config /etc/semaphore/config.yml --login '$ADMIN_USER'" \
        > "$DEST"
      echo "Saved admin token to $DEST"
    EOT
  }
}
