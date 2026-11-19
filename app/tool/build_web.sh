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
if [[ ! "$API_BASE_URL" =~ ^https?:// ]]; then
  echo "API_BASE_URL deve iniziare con https:// (o http:// in locale), ricevuto: $API_BASE_URL" >&2
  exit 1
fi
if [[ ! "${API_BASE_URL%/}" =~ /webhook$ ]]; then
  echo "Attenzione: API_BASE_URL di solito termina con /webhook (ricevuto: $API_BASE_URL)" >&2
fi

# Usa Flutter solo se è esattamente la versione fissata; altrimenti installa quella giusta.
current=""
if command -v flutter >/dev/null 2>&1; then
  current="$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' | head -n 1)"
fi
if [ "$current" != "$FLUTTER_VERSION" ]; then
  FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter-$FLUTTER_VERSION}"
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    echo "Installo Flutter $FLUTTER_VERSION in $FLUTTER_HOME (trovata: ${current:-nessuna})"
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
