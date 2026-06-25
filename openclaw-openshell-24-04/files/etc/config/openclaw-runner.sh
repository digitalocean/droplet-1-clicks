#!/bin/sh

export OPENCLAW_HOME="/sandbox/openclaw"

# 'exec' replaces the shell with the openclaw process for clean signal handling
exec OPENCLAW_HOME="/sandbox/openclaw" openclaw gateway --port 18789 --allow-unconfigured