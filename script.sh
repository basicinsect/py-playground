cat > build-python312.sh <<'BASH'
#!/usr/bin/env bash
set -euo pipefail

BUILD_ROOT="$PWD/python312-build"
OUTPUT_DIR="$PWD/output"

rm -rf "$BUILD_ROOT" "$OUTPUT_DIR"
mkdir -p "$BUILD_ROOT" "$OUTPUT_DIR"

if ! command -v uv >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

export UV_PYTHON_INSTALL_DIR="$BUILD_ROOT"

# Force installation into BUILD_ROOT, even if system Python 3.12 exists.
uv python install --reinstall 3.12

PYTHON_DIR="$(
    find "$BUILD_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name 'cpython-3.12*linux*x86_64*' |
    head -n 1
)"

if [[ -z "$PYTHON_DIR" ]]; then
    echo "Error: no managed Python installation found in $BUILD_ROOT" >&2
    find "$BUILD_ROOT" -maxdepth 2 -print >&2
    exit 1
fi

PYTHON_BIN="$PYTHON_DIR/bin/python3"

if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "Error: $PYTHON_BIN does not exist" >&2
    exit 1
fi

VERSION="$("$PYTHON_BIN" --version | awk '{print $2}')"
ARCHIVE="python-${VERSION}-linux-x86_64-uv.tar.gz"

echo "Packaging: $PYTHON_DIR"
"$PYTHON_BIN" --version

tar \
    -C "$BUILD_ROOT" \
    -czf "$OUTPUT_DIR/$ARCHIVE" \
    "$(basename "$PYTHON_DIR")"

cd "$OUTPUT_DIR"

sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

# Validate it contains Python but not the accidental /usr content.
tar -tzf "$ARCHIVE" | grep -q '/bin/python3'
if tar -tzf "$ARCHIVE" | grep -q '/share/terminfo/'; then
    echo "Error: archive unexpectedly contains system terminfo files" >&2
    exit 1
fi

echo
echo "Created:"
ls -lh "$ARCHIVE" "$ARCHIVE.sha256"
BASH

chmod +x build-python312.sh
./build-python312.sh