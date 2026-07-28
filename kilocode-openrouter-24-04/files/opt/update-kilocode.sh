#!/bin/bash

set -e

echo "Updating Kilo Code CLI to the latest version..."
npm update --global @kilocode/cli

echo "Kilo Code CLI updated successfully."
echo "Current version: $(kilo --version 2>/dev/null || echo 'unknown')"
