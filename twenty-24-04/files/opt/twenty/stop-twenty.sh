#!/bin/bash
set -e

echo "Stopping Twenty CRM..."
systemctl stop twenty
echo "Twenty CRM stopped."
