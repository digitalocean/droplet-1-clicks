#!/bin/bash
set -euo pipefail
systemctl start herdr.service
systemctl is-active herdr.service
