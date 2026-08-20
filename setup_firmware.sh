#!/usr/bin/env bash
# Setup / build / flash helper for the MPRLS pressure firmware (Adafruit QT Py M0).
#
# Usage:
#   ./setup_firmware.sh setup            # one-time: install arduino-cli, SAMD core, libraries
#   ./setup_firmware.sh compile          # compile firmware/micropressure_serial
#   ./setup_firmware.sh flash [port]     # compile + upload (default port: auto-detect)
#   ./setup_firmware.sh all [port]       # setup + compile + flash
#
# Can also be sourced to reuse the functions:
#   source setup_firmware.sh; mpr_compile; mpr_flash /dev/ttyACM0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKETCH_DIR="$REPO_DIR/firmware/micropressure_serial"
FQBN="adafruit:samd:adafruit_qtpy_m0"
ADAFRUIT_INDEX="https://adafruit.github.io/arduino-board-index/package_adafruit_index.json"
BINDIR="${BINDIR:-$HOME/.local/bin}"

mpr_setup() {
    if ! command -v arduino-cli >/dev/null 2>&1 && [ ! -x "$BINDIR/arduino-cli" ]; then
        echo ">> Installing arduino-cli to $BINDIR"
        mkdir -p "$BINDIR"
        curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR="$BINDIR" sh
    fi
    export PATH="$BINDIR:$PATH"
    arduino-cli config init --overwrite >/dev/null
    arduino-cli config add board_manager.additional_urls "$ADAFRUIT_INDEX"
    arduino-cli core update-index
    arduino-cli core install adafruit:samd
    arduino-cli lib install "SparkFun MicroPressure Library" "Adafruit NeoPixel"
    echo ">> Setup done: $(arduino-cli version)"
}

mpr_compile() {
    export PATH="$BINDIR:$PATH"
    arduino-cli compile --fqbn "$FQBN" "$SKETCH_DIR"
}

# Find the QT Py M0's port. With several boards attached, flash one at a time
# or pass the port explicitly.
mpr_find_port() {
    export PATH="$BINDIR:$PATH"
    local ports
    ports=$(arduino-cli board list | awk '/QT Py M0|adafruit_qtpy_m0/ {print $1}')
    if [ -z "$ports" ]; then
        echo "ERROR: no QT Py M0 found. Plug in the board (double-tap reset if needed)." >&2
        arduino-cli board list >&2
        return 1
    fi
    if [ "$(echo "$ports" | wc -l)" -gt 1 ]; then
        echo "ERROR: multiple QT Py M0 boards found — pass a port explicitly:" >&2
        echo "$ports" >&2
        return 1
    fi
    echo "$ports"
}

mpr_flash() {
    export PATH="$BINDIR:$PATH"
    local port="${1:-}"
    if [ -z "$port" ]; then
        port="$(mpr_find_port)" || return 1
    fi
    mpr_compile
    echo ">> Uploading to $port"
    arduino-cli upload -p "$port" --fqbn "$FQBN" "$SKETCH_DIR"
    echo ">> Done. Test with: python $REPO_DIR/read_pressure.py"
}

# Dispatch only when executed, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    set -euo pipefail
    cmd="${1:-}"
    case "$cmd" in
        setup)   mpr_setup ;;
        compile) mpr_compile ;;
        flash)   mpr_flash "${2:-}" ;;
        all)     mpr_setup; mpr_flash "${2:-}" ;;
        *)       grep '^#' "$0" | head -11; exit 1 ;;
    esac
fi
