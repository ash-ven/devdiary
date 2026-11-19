#!/usr/bin/env bash
# Build riproducibile dell'app web, usato dalla CI e da Render Static Site.
# Uso (dalla radice del repository o da qualsiasi cartella):
#   API_BASE_URL=https://devdiary-api.onrender.com/webhook ./app/tool/build_web.sh
set -euo pipefail

FLUTTER_VERSION="3.50.0"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "API_BASE_URL mancante: indica l'indirizzo dei webhook, es. https://devdiary-api.onrender.com/webhook" >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter}"
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    echo "Installo Flutter $FLUTTER_VERSION in $FLUTTER_HOME"
    git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

cd "$APP_DIR"
flutter --version
flutter config --no-analytics >/dev/null
flutter pub get
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL="$API_BASE_URL"
echo "Build pronta in $APP_DIR/build/web (API: $API_BASE_URL)"
