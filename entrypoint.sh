#!/bin/bash
set -e

echo "Running entrypoint.sh..."
/usr/local/bin/generate.sh "$@"
