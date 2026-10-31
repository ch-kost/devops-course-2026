#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MODE=${1:-}
[[ $# -le 1 && ( -z "$MODE" || "$MODE" == --dry-run ) ]] || { echo 'Usage: scripts/deploy.sh [--dry-run]' >&2; exit 1; }
[[ -f "$ROOT/site/index.html" ]] || { echo 'site/index.html missing; deployment refused' >&2; exit 1; }
[[ -z $(git -C "$ROOT" status --porcelain) ]] || { echo 'Uncommitted changes; deployment refused' >&2; exit 1; }
REMOTE=devops
REMOTE_DIR=/var/www/devops-site
URL=https://devops.local/
CERT=${CA_CERT:-$HOME/devops.crt}
CFG=${SSH_CONFIG:-$HOME/.ssh/config}
RSYNC=(rsync -avz --delete --chmod=D755,F644 -e "/usr/bin/ssh -F $CFG -o BatchMode=yes -o ConnectTimeout=5")
[[ "$MODE" != --dry-run ]] || RSYNC+=(--dry-run)
"${RSYNC[@]}" "$ROOT/site/" "$REMOTE:$REMOTE_DIR/"
if [[ "$MODE" != --dry-run ]]; then curl --noproxy '*' -fsS --connect-timeout 5 --max-time 15 --cacert "$CERT" "$URL" >/dev/null; fi
echo "Deployment OK: $(git -C "$ROOT" rev-parse --short HEAD) ${MODE:-applied}"
