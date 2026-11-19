#!/bin/sh
# Avvio del container DevDiary API: credenziale, workflow, attivazione, poi proxy + n8n.
set -eu

for var in MONGODB_URI N8N_ENCRYPTION_KEY RESET_TOKEN; do
  eval "value=\${$var:-}"
  if [ -z "$value" ]; then
    echo "DevDiary API: manca la variabile d'ambiente $var" >&2
    exit 1
  fi
done

export MONGODB_DATABASE="${MONGODB_DATABASE:-dev_diary}"
export ALLOWED_ORIGINS="${ALLOWED_ORIGINS:-*}"
export DEMO_MODE="${DEMO_MODE:-false}"
export PORT="${PORT:-10000}"

work=/tmp/devdiary
rm -rf "$work"
mkdir -p "$work/workflows"

node -e '
const fs = require("node:fs");
fs.writeFileSync(process.argv[1], JSON.stringify([{
  id: "DevDiaryMongo001",
  name: "MongoDB DevDiary",
  type: "mongoDb",
  data: {
    configurationType: "connectionString",
    connectionString: process.env.MONGODB_URI,
    database: process.env.MONGODB_DATABASE,
  },
}]));
' "$work/cred.json"

node /opt/devdiary/docker/render-workflows.js /opt/devdiary/workflows/dist "$work/workflows"

n8n import:credentials --input="$work/cred.json"
n8n import:workflow --separate --input="$work/workflows"
n8n update:workflow --all --active=true
rm -f "$work/cred.json"

exec node /opt/devdiary/proxy/main.js
