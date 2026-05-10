# syntax=docker/dockerfile:1.4

# SPDX-FileCopyrightText: Copyright (c) 2025-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# OpenClaw sandbox image for OpenShell
#
# Builds on the community base sandbox and adds OpenClaw.
# Build:  docker build -t openshell-openclaw --build-arg BASE_IMAGE=openshell-base .
# Run:    openshell sandbox create --from openclaw

ARG BASE_IMAGE=ghcr.io/nvidia/openshell-community/sandboxes/base:latest
FROM ${BASE_IMAGE}

USER root

# Install OpenClaw CLI (pinned to fix GHSA-rchv-x836-w7xp, GHSA-6mgf-v5j7-45cr,
# GHSA-5wcw-8jjv-m286)
RUN npm install -g openclaw@2026.3.11

# Copy sandbox policy
COPY policy.yaml /etc/openshell/policy.yaml

# Create OpenClaw workspaces (Added /sandbox/openclaw here)
RUN mkdir -p /sandbox/openclaw /sandbox/openclaw/.openclaw && \
    chown -R sandbox:sandbox /sandbox/openclaw /sandbox/openclaw/.openclaw

USER sandbox

# 1. Copy openclaw.json from local to container, assigning it to the sandbox user
COPY --chown=sandbox:sandbox openclaw.json /sandbox/openclaw/.openclaw/openclaw.json

# 2. Set the environment variable natively for the container
ENV OPENCLAW_HOME="/sandbox/openclaw"

# 3. Launch openclaw on container start (Using JSON array format so it runs as PID 1)
ENTRYPOINT ["openclaw", "gateway", "--port", "18789", "--allow-unconfigured"]