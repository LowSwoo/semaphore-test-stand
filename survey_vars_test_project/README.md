# Survey Vars — Terraform

Creates a `Survey Vars` project in a running [Semaphore UI](https://semaphoreui.com)
instance for testing **survey variables**, both from the UI and from
integrations (incoming webhooks).

## Resources

- Project `Survey Vars`, keys (`none`, `semaphore_test_stand`, `webhook_secret`),
  repository `semaphore-test-stand-tests`, inventory `localhost`, environment `default`.
- Template `survey-vars-all-types` (app **bash**, script
  `survey-vars-all-types/print-vars.sh`) — prints every survey variable it receives.

| Survey var        | Type    | Required | Values |
|-------------------|---------|----------|--------|
| `str_required`    | string  | yes      | |
| `str_optional`    | string  | no       | |
| `str_described`   | string  | no       | has a description |
| `int_required`    | integer | yes      | |
| `int_optional`    | integer | no       | |
| `secret_required` | secret  | yes      | |
| `secret_optional` | secret  | no       | |
| `enum_required`   | enum    | yes      | `dev`, `staging`, `prod` |
| `enum_optional`   | enum    | no       | `red`, `green`, `blue` |

- Integrations for this template (each with an alias / webhook URL). Survey
  values are passed via `task_params.environment`:

| Integration            | Auth                               | Survey values |
|------------------------|------------------------------------|---------------|
| `survey-all-values`    | none                               | all vars |
| `survey-required-only` | none                               | required vars only |
| `survey-no-values`     | none                               | none |
| `survey-token-auth`    | token, header `X-Semaphore-Token`  | all vars |
| `survey-hmac-auth`     | hmac, header `X-Hub-Signature-256` | all vars |

## Setup

Requires a reachable Semaphore instance and an API token (see
[ansible_vaults_test_project/README.md](../ansible_vaults_test_project/README.md)
for how to get one), and the SSH key at `../workspaces/default/id_rsa`.

```sh
cd survey_vars_test_project
cp terraform.tfvars.example terraform.tfvars   # set api_token
terraform init
terraform apply
terraform output webhook_urls
```

`webhook_secret` (default `fake-webhook-secret`) is the shared secret of the
token / hmac integrations.

## Checks

**UI:** run `survey-vars-all-types`, fill the survey; the task log must show
every entered value in the `defined on template` table (`<unset>` for skipped
optional ones).

**Integrations:**

```sh
curl -k -X POST "$(terraform output -json webhook_urls | jq -r .all_values)"
curl -k -X POST "$(terraform output -json webhook_urls | jq -r .required_only)"
curl -k -X POST "$(terraform output -json webhook_urls | jq -r .no_values)"

# token auth
curl -k -X POST -H "X-Semaphore-Token: fake-webhook-secret" \
  "$(terraform output -json webhook_urls | jq -r .token_auth)"

# hmac auth
BODY='{}'
SIG="sha256=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac fake-webhook-secret | awk '{print $NF}')"
curl -k -X POST -H "Content-Type: application/json" -H "X-Hub-Signature-256: $SIG" \
  -d "$BODY" "$(terraform output -json webhook_urls | jq -r .hmac_auth)"
```

Expected: each request starts a task of `survey-vars-all-types`; its log shows
the values from the integration's `task_params.environment`. Requests to the
token/hmac integrations without a valid header must be rejected.
