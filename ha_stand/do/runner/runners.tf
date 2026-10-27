resource "semaphoreui_runner" "runner" {
  for_each           = local.config.runners
  name               = each.value.name
  max_parallel_tasks = 10
  active             = true
  tags               = ["local", "dev"]
  is_default         = false
}

resource "digitalocean_droplet" "runner" {
  for_each = local.config.runners

  name     = "runner-${semaphoreui_runner.runner[each.key].id}-${each.value.name}"
  image    = var.image
  size     = var.size
  region   = var.region
  vpc_uuid = digitalocean_vpc.main.id

  ssh_keys = [data.digitalocean_ssh_key.default.id]
  tags     = [digitalocean_tag.runner.id]

  user_data = templatefile("${path.module}/../../shared/cloud-init/runner-systemd.yaml.tftpl", {
    runner_id = semaphoreui_runner.runner[each.key].id
  })

  connection {
    type = "ssh"
    user = "root"
    host = self.ipv4_address
    agent = true
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/semaphore",
    ]
  }

  provisioner "file" {
    content = templatefile("${path.module}/../../shared/runner/runner-config.json.tftpl", {
      web_root             = local.web_root
      runner_name          = "${local.prefix}-${each.value.name}"
      tags                 = ["local", "dev"],
      runner_executor_type = each.value.runner_executor_type
    })
    destination = "/etc/semaphore/runner-config.json"
  }

  provisioner "file" {
    content     = file("${path.module}/../../shared/runner/semaphore-runner.service")
    destination = "/etc/systemd/system/semaphore-runner.service"
  }

  provisioner "remote-exec" {
    inline = concat([
      "snap wait system seed.loaded",
      "snap install doctl",
      "snap connect doctl:kube-config",
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "mkdir -p /root/.config",
      "mkdir -p /root/.kube",
      "doctl auth init --access-token ${var.do_token}",
      ],
    each.value.runner_executor_type == "k8s" ? ["doctl kubernetes cluster kubeconfig save ${var.do_k8s_cluster}"] : [])
  }

  provisioner "remote-exec" {
    inline = [
      "curl -o semaphore_${var.semaphore_version}_linux_amd64.tar.gz -L https://github.com/semaphoreui/semaphore/releases/download/v${var.semaphore_version}/semaphore_${var.semaphore_version}_linux_amd64.tar.gz",
      "tar xf semaphore_${var.semaphore_version}_linux_amd64.tar.gz",
      "mv semaphore /usr/local/bin/",

      # cloud-init installs docker.io in parallel; create the group up front so
      # membership does not depend on which side finishes first. docker.io's
      # postinst reuses an existing docker group.
      "getent group docker >/dev/null || groupadd --system docker",
      "id -u semaphore >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin semaphore",
      "usermod -aG docker semaphore",
      "chmod 0600 /etc/semaphore/runner-config.json",
      "chmod 0644 /etc/systemd/system/semaphore-runner.service",
      "chown -R semaphore:semaphore /etc/semaphore",

      "install -d -m 0700 -o semaphore -g semaphore /home/semaphore/.kube",
      "cp /root/.kube/config /home/semaphore/.kube/config",
      "chown semaphore:semaphore /home/semaphore/.kube/config",
      "chmod 0600 /home/semaphore/.kube/config",

      "install -d -m 0700 -o semaphore -g semaphore /home/semaphore/.config",
      "cp -r /root/.config/doctl /home/semaphore/.config/doctl",
      "chown -R semaphore:semaphore /home/semaphore/.config",

      "systemctl daemon-reload",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        token=""
        for i in $(seq 1 5); do

          echo "attempting to obtain registration token for runner ${semaphoreui_runner.runner[each.key].id} (attempt $i)..." >> /tmp/runner-registration.log

          token=$(curl -XPOST -s \
            -H 'Authorization: Bearer ${local.api_token}' \
            -H 'content-type: application/json' \
            ${local.api_base_url}/runners/${semaphoreui_runner.runner[each.key].id}/registration-token \
            | jq -r .registration_token)

          if [ -n "$token" ] && [ "$token" != "null" ]; then
            break
          fi

          echo "registration token is empty, retrying ($i/5)..." >> /tmp/runner-registration.log
          sleep 5
        done

        if [ -z "$token" ] || [ "$token" = "null" ]; then
          echo "failed to obtain registration token after 5 attempts" >> /tmp/runner-registration.log
          exit 1
        fi

        echo "obtained registration token $token, registering runner..." >> /tmp/runner-registration.log

        echo $token | /usr/local/bin/semaphore runner register \
              --stdin-registration-token \
              --config /etc/semaphore/runner-config.json

        echo "runner registered successfully" >> /tmp/runner-registration.log
      EOT
      ,
      "systemctl enable --now semaphore-runner",
    ]
  }
}
