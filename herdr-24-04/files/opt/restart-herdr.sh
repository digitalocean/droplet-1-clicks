#!/bin/bash
set -euo pipefail
systemctl restart herdr.service
systemctl is-active herdr.service
