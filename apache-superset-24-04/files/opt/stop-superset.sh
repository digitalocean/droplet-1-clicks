#!/bin/bash
echo "Stopping Apache Superset..."
systemctl stop superset
echo "Superset stopped. (Caddy left running; stop with: systemctl stop caddy)"
