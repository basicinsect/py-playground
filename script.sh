cat > build-python312-wsl1.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

BUILD="$PWD/python312-build"
OUTPUT="$PWD/output"

rm -rf "$BUILD" "$OUTPUT" /tmp/python312-test
mkdir -p "$BUILD" "$OUTPUT" /tmp/python312-test

command -v uv >/dev/null 2>&1 || {
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
}

UV_PYTHON_INSTALL_DIR="$BUILD" uv python install --reinstall 3.12

PYTHON_DIR="$(find "$BUILD" -mindepth 1 -maxdepth 1 -type d -name 'cpython-3.12*linux*x86_64*' -print -quit)"
test -n "$PYTHON_DIR"
test -x "$PYTHON_DIR/bin/python3"

VERSION="$("$PYTHON_DIR/bin/python3" --version | awk '{print $2}')"
ROOT="$(basename "$PYTHON_DIR")"
NAME="python-${VERSION}-linux-x86_64-wsl1.tar.gz"

tar \
    --hard-dereference \
    --exclude="$ROOT/share/terminfo" \
    --exclude="$ROOT/share/terminfo/*" \
    --exclude="$ROOT/share/man" \
    --exclude="$ROOT/share/man/*" \
    -C "$BUILD" \
    -czf "$OUTPUT/$NAME" \
    "$ROOT"

cd "$OUTPUT"

sha256sum "$NAME" > "$NAME.sha256"

tar -xzf "$NAME" -C /tmp/python312-test

TEST_PYTHON="/tmp/python312-test/$ROOT/bin/python3"
test -x "$TEST_PYTHON"

"$TEST_PYTHON" -c 'import bz2,ctypes,hashlib,lzma,sqlite3,ssl,venv,sys; print("VALID:", sys.version); print(ssl.OPENSSL_VERSION); print("SQLite:", sqlite3.sqlite_version)'

if tar -tzf "$NAME" | grep -q '/share/terminfo/'; then
    echo "ERROR: terminfo remains in archive" >&2
    exit 1
fi

echo
echo "WSL1 archive created:"
ls -lh "$NAME" "$NAME.sha256"
BASH

chmod +x build-python312-wsl1.sh && ./build-python312-wsl1.sh