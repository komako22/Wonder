#!/usr/bin/env bash
set -euo pipefail

APP="${1:?Usage: sign-app.sh /path/to/Wonder.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_MODE="${WONDER_SIGNING_MODE:-local}"

if [[ "$SIGNING_MODE" == "adhoc" ]]; then
  codesign --force --deep \
    --sign - \
    --identifier com.wonder.translate \
    "$APP"
  exit 0
fi

if [[ "$SIGNING_MODE" != "local" ]]; then
  echo "Unsupported WONDER_SIGNING_MODE: $SIGNING_MODE (expected local or adhoc)." >&2
  exit 1
fi

SIGNING_DIR="$ROOT/.local-signing"
KEYCHAIN="$SIGNING_DIR/WonderDevelopment.keychain-db"
PASSWORD_FILE="$SIGNING_DIR/keychain-password"
CERTIFICATE="$SIGNING_DIR/WonderDevelopment.pem"
IDENTITY_NAME="Wonder Local Development"

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if [[ ! -f "$KEYCHAIN" ]]; then
  PASSWORD="$(openssl rand -hex 32)"
  printf '%s' "$PASSWORD" > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"

  PRIVATE_KEY="$SIGNING_DIR/private-key.pem"
  IDENTITY_ARCHIVE="$SIGNING_DIR/identity.p12"
  security create-keychain -p "$PASSWORD" "$KEYCHAIN"
  security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
  security set-keychain-settings -lut 21600 "$KEYCHAIN"

  openssl req -x509 -newkey rsa:2048 \
    -keyout "$PRIVATE_KEY" \
    -out "$CERTIFICATE" \
    -days 3650 \
    -nodes \
    -subj '/CN=Wonder Local Development/O=Wonder/' \
    -addext 'keyUsage=critical,digitalSignature,keyCertSign' \
    -addext 'extendedKeyUsage=critical,codeSigning' \
    -addext 'basicConstraints=critical,CA:TRUE'
  openssl pkcs12 -export -legacy \
    -out "$IDENTITY_ARCHIVE" \
    -inkey "$PRIVATE_KEY" \
    -in "$CERTIFICATE" \
    -passout "pass:$PASSWORD"
  security import "$IDENTITY_ARCHIVE" \
    -k "$KEYCHAIN" \
    -P "$PASSWORD" \
    -T /usr/bin/codesign
  security add-trusted-cert -d -r trustRoot -p codeSign \
    -k "$KEYCHAIN" "$CERTIFICATE"
  security set-key-partition-list \
    -S apple-tool:,apple:,codesign: \
    -s -k "$PASSWORD" "$KEYCHAIN"
  rm -f "$PRIVATE_KEY" "$IDENTITY_ARCHIVE"
fi

PASSWORD="$(<"$PASSWORD_FILE")"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"

CURRENT_KEYCHAINS=()
while IFS= read -r CURRENT_KEYCHAIN; do
  CURRENT_KEYCHAIN="${CURRENT_KEYCHAIN//\"/}"
  CURRENT_KEYCHAIN="${CURRENT_KEYCHAIN#${CURRENT_KEYCHAIN%%[![:space:]]*}}"
  [[ -n "$CURRENT_KEYCHAIN" ]] && CURRENT_KEYCHAINS+=("$CURRENT_KEYCHAIN")
done < <(security list-keychains -d user)

KEYCHAIN_REGISTERED=false
for CURRENT_KEYCHAIN in "${CURRENT_KEYCHAINS[@]}"; do
  if [[ "$CURRENT_KEYCHAIN" == "$KEYCHAIN" ]]; then
    KEYCHAIN_REGISTERED=true
    break
  fi
done

if [[ "$KEYCHAIN_REGISTERED" == false ]]; then
  security list-keychains -d user -s "$KEYCHAIN" "${CURRENT_KEYCHAINS[@]}" >/dev/null
fi

IDENTITY_HASH="$(security find-identity -v -p codesigning "$KEYCHAIN" | awk -v name="$IDENTITY_NAME" 'index($0, name) { print $2; exit }')"
if [[ -z "$IDENTITY_HASH" ]]; then
  echo "Wonder local signing identity is unavailable." >&2
  exit 1
fi

codesign --force --deep \
  --sign "$IDENTITY_HASH" \
  --keychain "$KEYCHAIN" \
  --identifier com.wonder.translate \
  "$APP"
