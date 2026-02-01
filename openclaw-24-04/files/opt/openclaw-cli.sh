#!/bin/bash
# Helper script to run OpenClaw CLI commands as the openclaw user
su - openclaw -c "openclaw $*"
