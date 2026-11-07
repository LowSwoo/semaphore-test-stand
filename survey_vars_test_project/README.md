# Survey Vars — Terraform

Creates a `Survey Vars` project in a running [Semaphore UI](https://semaphoreui.com)
instance for testing **survey variables**, both from the UI and from an
integration (incoming webhook) with extractors.

## Resources

- Project `Survey Vars`, keys (`none`, `semaphore_test_stand`),
  repository `semaphore-test-stand-tests`, inventory `localhost`, environment `default`.
- Template `survey-vars-all-types` (app **bash**, script
  `survey-vars-all-types/print-vars.sh`, source in
  [`tests_repo/survey-vars-all-types`](../tests_repo/survey-vars-all-types)) —
  prints every survey variable it receives.

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

- Integration `survey-vars` (no auth) for this template, with an alias
  (webhook URL) and one extractor per survey variable. Extractors write into
  the task environment (extra vars), which Semaphore passes to the bash script
  as `name=value` arguments.

| Survey var        | Source    | Key |
|-------------------|-----------|-----|
| `str_required`    | JSON body | `str_required` |
| `str_optional`    | JSON body | `str_optional` |
| `str_described`   | JSON body | `str_described` |
| `int_required`    | JSON body | `int_required` |
| `int_optional`    | JSON body | `int_optional` |
| `secret_required` | JSON body | `secret_required` |
| `secret_optional` | header    | `X-Secret-Optional` |
| `enum_required`   | JSON body | `enum_required` |
| `enum_optional`   | JSON body | `options.color` (nested) |

The semaphoreui provider does not support extractors yet, so they are created
directly through the Semaphore API with the
[`Mastercard/restapi`](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs)
provider (it uses the same `api_base_url` / `api_token`). Any change to an
extractor recreates it.

## Setup

Requires a reachable Semaphore instance and an API token (see
[ansible_vaults_test_project/README.md](../ansible_vaults_test_project/README.md)
for how to get one), and the SSH key at `../workspaces/default/id_rsa`.
`api_token` must be set in `terraform.tfvars` (the restapi provider does not
read `SEMAPHOREUI_API_TOKEN`).

```sh
cd survey_vars_test_project
cp terraform.tfvars.example terraform.tfvars   # set api_token
terraform init
terraform apply
terraform output webhook_url
```

## Checks

**UI:** run `survey-vars-all-types`, fill the survey; the task log must show
every entered value in the `defined on template` table (`<unset>` for skipped
optional ones).

**Integration:**

```sh
URL=$(terraform output -raw webhook_url)

# all values
curl -k -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "X-Secret-Optional: fake-optional-secret" \
  -d '{
    "str_required": "hello world",
    "str_optional": "optional value",
    "str_described": "spaces & special chars: !@#$%^*()",
    "int_required": 42,
    "int_optional": 7,
    "secret_required": "fake-integration-secret",
    "enum_required": "staging",
    "options": { "color": "green" }
  }'

# required values only — optional vars must be <unset>
curl -k -X POST "$URL" -H "Content-Type: application/json" \
  -d '{"str_required":"x","int_required":1,"secret_required":"s","enum_required":"prod"}'

# empty body — all vars <unset> (except secret_optional, see below)
curl -k -X POST "$URL" -H "Content-Type: application/json" -d '{}'
```

Expected: each request starts a `survey-vars-all-types` task; its log shows
the values from the request body / header in the `defined on template` table.

Note: a header extractor always sets its variable — to an empty string when
the header is missing — so without `X-Secret-Optional` the log shows
`secret_optional` with an empty value, not `<unset>`.
