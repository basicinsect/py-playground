#!/usr/bin/env bash
set -euo pipefail

BUILD="$PWD/python312-build"
OUTPUT="$PWD/output"

rm -rf "$BUILD" "$OUTPUT"
mkdir -p "$BUILD" "$OUTPUT"

command -v uv >/dev/null 2>&1 || {
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
}

UV_PYTHON_INSTALL_DIR="$BUILD" uv python install --reinstall 3.12

PYTHON_DIR="$(find "$BUILD" -mindepth 1 -maxdepth 1 -type d -name 'cpython-3.12*linux*x86_64*' -print -quit)"
test -n "$PYTHON_DIR"
test -x "$PYTHON_DIR/bin/python3"

VERSION="$("$PYTHON_DIR/bin/python3" --version | awk '{print $2}')"
NAME="python-${VERSION}-linux-x86_64-uv.tar.gz"

# Preserve symbolic links, but store hard-linked files as independent files.
tar --hard-dereference -C "$BUILD" -czf "$OUTPUT/$NAME" "$(basename "$PYTHON_DIR")"

cd "$OUTPUT"
sha256sum "$NAME" > "$NAME.sha256"

rm -rf /tmp/python312-test
mkdir -p /tmp/python312-test
tar -xzf "$NAME" -C /tmp/python312-test

"/tmp/python312-test/$(basename "$PYTHON_DIR")/bin/python3" -c \
'import ssl, sqlite3, venv; print("VALID:", __import__("sys").version); print(ssl.OPENSSL_VERSION)'

echo
echo "Created:"
ls -lh "$NAME" "$NAME.sha256"
