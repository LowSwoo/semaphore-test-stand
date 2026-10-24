# Stand 1 — Terraform

Manages a local [Semaphore UI](https://semaphoreui.com) instance via the
[`semaphoreui/semaphore`](https://registry.terraform.io/providers/semaphoreui/semaphore/latest/docs)
Terraform provider.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- Semaphore running at `http://localhost:3000` (default API base URL)
- An API token (browser console while logged in):

```javascript
fetch("/api/user/tokens", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({}),
})
  .then((res) => res.json())
  .then((data) => console.log("api_token = " + data.id));
```

## Setup

```sh
cd stands/ansible_vaults_test_project
cp terraform.tfvars.example terraform.tfvars   # edit api_token
terraform init
```

Alternatively, export credentials and omit `terraform.tfvars`:

```sh
export SEMAPHOREUI_API_BASE_URL="http://localhost:3000/api"
export SEMAPHOREUI_API_TOKEN="your token"
terraform init
```

Add `.tf` files here for projects, repositories, inventories, templates, and
other Semaphore resources as the stand grows.
