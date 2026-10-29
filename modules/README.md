# Shared modules

Building blocks used by the stands' root modules. Each module keeps its
cloud-init template in `templates/`.

| Module                         | Used by                | Creates                                                                 |
| ------------------------------ | ---------------------- | ----------------------------------------------------------------------- |
| [`do/postgres`](do/postgres)   | `ha_stand`, `sso_stand` | PostgreSQL droplet listening on the VPC                                 |
| [`do/redis`](do/redis)         | `ha_stand`             | Redis Sentinel cluster: `redis-1` master + replicas, Sentinel on each   |
| [`do/semaphore`](do/semaphore) | `ha_stand`, `sso_stand` | Semaphore UI nodes; `redis` adds the `ha:` block, `port` < 1024 adds `CAP_NET_BIND_SERVICE`, `extra_config` appends top-level `config.yml` keys |
| [`do/idp`](do/idp)             | `sso_stand`            | `idp` droplet with OpenLDAP/Dex, its firewall, the `<prefix>-dex` record, and `semaphore_config` for `do/semaphore` |

Networking (VPC, firewalls, tags), the DigitalOcean project and DNS for the UI
stay in each stand: they differ between stands.

A template change changes `user_data` and therefore replaces the droplets of
every stand that uses the module. Check the plan of `ha_stand` and `sso_stand`
after editing one.
