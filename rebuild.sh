#!/usr/bin/env bash
# Rebuild build/archive.zip from pieces/ and compare against the expected SHA256.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
"${PYTHON:-python3}" rebuild.py "${1:-build/archive.zip}"
