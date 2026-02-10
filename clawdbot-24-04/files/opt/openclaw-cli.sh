#!/bin/bash
# Helper script to run Openclaw CLI commands as the openclaw user
su - openclaw -c "openclaw $*"