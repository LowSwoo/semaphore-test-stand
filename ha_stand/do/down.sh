#!/usr/bin/env zsh
# Destroy a whole stand: runners first (they are registered on the servers),
# then the servers.
#
#   ./down.sh [<workspace>] [--skip-server]
#
# --skip-server is forwarded to down_runners.sh: destroy the runner droplets
# without deregistering them on the Semaphore server (use when the servers are
# already gone or the admin token in s3://<bucket>/<workspace>/admin.token is lost).
set -e

./down_runners.sh "$@"

./down_servers.sh "$@"
