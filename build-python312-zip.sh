#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
OUTPUT_DIR="${OUTPUT_DIR:-$PWD}"

command -v curl >/dev/null || {
    echo "Error: curl is required" >&2
    exit 1
}

# Install zip if Codespaces does not have it.
if ! command -v zip >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y zip
fi

# Install uv if unavailable.
if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(realpath "$OUTPUT_DIR")"

echo "Installing Python $PYTHON_VERSION..."
uv python install "$PYTHON_VERSION"

# Resolve uv's symlinks to the actual installation.
PYTHON_BIN="$(realpath "$(uv python find "$PYTHON_VERSION")")"
PYTHON_ROOT="$(realpath "$(dirname "$PYTHON_BIN")/..")"
ACTUAL_VERSION="$("$PYTHON_BIN" --version | awk '{print $2}')"

BASE_NAME="python-${ACTUAL_VERSION}-linux-x86_64-uv"
TARBALL="$OUTPUT_DIR/$BASE_NAME.tar.gz"
CHECKSUM="$TARBALL.sha256"
ZIP_FILE="$OUTPUT_DIR/$BASE_NAME.zip"

STAGING="$(mktemp -d)"
PACKAGE_DIR="$STAGING/cpython-${ACTUAL_VERSION}-linux-x86_64-gnu"

cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

echo "Copying actual Python installation..."
mkdir -p "$PACKAGE_DIR"

# -L follows symlinks instead of packaging broken Codespaces links.
cp -aL "$PYTHON_ROOT"/. "$PACKAGE_DIR"/

test -x "$PACKAGE_DIR/bin/python3" || {
    echo "Error: staged package has no bin/python3" >&2
    exit 1
}

"$PACKAGE_DIR/bin/python3" --version

echo "Creating tar.gz..."
tar \
    -C "$STAGING" \
    -czf "$TARBALL" \
    "$(basename "$PACKAGE_DIR")"

# Verify that tar.gz contains the real Python executable.
tar -tzf "$TARBALL" |
    grep -q "^$(basename "$PACKAGE_DIR")/bin/python3$" || {
        echo "Error: tar.gz does not contain bin/python3" >&2
        exit 1
    }

# Write a relative filename into the checksum.
(
    cd "$OUTPUT_DIR"
    sha256sum "$(basename "$TARBALL")" \
        > "$(basename "$CHECKSUM")"
)

echo "Creating ZIP..."
rm -f "$ZIP_FILE"

(
    cd "$OUTPUT_DIR"
    zip -9 "$(basename "$ZIP_FILE")" \
        "$(basename "$TARBALL")" \
        "$(basename "$CHECKSUM")"
)

unzip -t "$ZIP_FILE" >/dev/null

echo
echo "Created:"
ls -lh "$ZIP_FILE"
echo
echo "Download this one file:"
echo "$ZIP_FILE"
