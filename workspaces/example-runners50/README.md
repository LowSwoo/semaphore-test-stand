# runners50 — many runners vs. PostgreSQL sessions (Semaphore 2.19.17, HA)

Reproduces a customer report: 3 UI nodes on 2.19.17 in HA mode and 50 runners
(job check interval raised from 1s to 5s) put heavy load on a shared
PostgreSQL, which sees more than 60 concurrent sessions from the UI nodes.

| Role       | Count | Notes                                                                 |
| ---------- | ----- | --------------------------------------------------------------------- |
| UI nodes   | 3     | 2.19.17, `ha.engine: redis`, `ha.redis.addr` → redis-1 (ams3)          |
| Runners    | 50    | 2.19.17, `check_interval_seconds: 5`, local executor, one droplet each (fra1) |
| PostgreSQL | 1     | `max_connections = 200`                                               |
| Redis      | 1     | no Sentinel: 2.19.x only knows a single address                       |

That is 55 droplets: check the droplet limit of the DigitalOcean account.

## Why runners load the database

Per runner, 2.19.17 sends to `/api/internal/runners`:

- `PUT` every **1 s**: progress report and heartbeat. Not affected by
  `check_interval_seconds`.
- `GET` every `check_interval_seconds`: asks for new jobs.

Each request looks the runner up by its token (`select … from runner where
token = ?`, then its tags); the `GET` also runs `update runner set touched = …`.
With 50 idle runners at 5 s that is about 60 requests and 130 queries per
second (about 250 queries at 1 s); running jobs add task status and log writes.

The UI nodes keep Go's `database/sql` pool at its defaults (2.19.17 has no
setting for it): no limit on open connections, at most 2 idle per node, no
lifetime or idle timeout. The sessions of a node are its queries in flight
plus up to 2 idle ones. When queries take longer (network latency, a loaded
shared server), more of them overlap, the pool opens extra connections and
closes them right after use, and every new session costs PostgreSQL a fork and
a SCRAM handshake.

## Run

```sh
cp -r workspaces/example-runners50 workspaces/runners50   # set subscription_key
cd ha_stand/do
./up.sh runners50
```

Terraform creates at most 10 runner droplets at a time;
`TF_CLI_ARGS_apply=-parallelism=25 ./up.sh runners50` is faster.

## Measure

```sh
./db_sessions.sh runners50 5 | tee runners50-sessions.log
```

Prints, every 5 s, the sessions of the `semaphore` database per UI node
(active / idle / idle in transaction), sessions opened per second (connection
churn) and transactions per second. See the header of
[db_sessions.sh](../../ha_stand/do/db_sessions.sh).

1. **Baseline.** Wait until all 50 runners show as online in the UI, then
   watch a few minutes.
2. **Slow database.** Add round-trip latency between the UI nodes and
   PostgreSQL, as on a remote or shared database platform, and watch
   sessions and `new/s` grow:

   ```sh
   ./db_latency.sh runners50 20ms    # or "20ms 5ms" with jitter
   ./db_latency.sh runners50 off
   ```

3. **Fewer runners.** Set `runner_count: 25` and run `./up.sh runners50`
   again (the server apply is a no-op), so you can compare 25 and 50 runners.
4. **Running jobs.** Create a project on the stand, e.g. with
   [`survey_vars_test_project`](../../survey_vars_test_project)
   (`api_base_url = "https://runners50-lb.<parent_domain>/api"`, `api_token`
   from `/tmp/runners50-admin.token`), and run tasks: progress reports then
   carry jobs and logs.

Changing `runner_check_interval_seconds` needs new runner droplets: the
runner config is written once, at provisioning (`./down_runners.sh runners50`,
then `./up.sh runners50`).

What the sessions last ran, on the postgres droplet:

```sh
ssh root@<postgres public ip> "sudo -u postgres psql -c \"select client_addr, state, left(query, 70) as query, count(*) from pg_stat_activity where datname = 'semaphore' group by 1, 2, 3 order by 4 desc\""
```

## Tear down

```sh
./down.sh runners50
```
