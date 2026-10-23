# Multi-stage build for Strapi
# Strapi 5.48.1+ requires Node >= 22 (recommended 24); use Node 22 LTS Alpine.
FROM node:22-alpine AS build

# Install dependencies for building
RUN apk add --no-cache \
    build-base \
    gcc \
    autoconf \
    automake \
    zlib-dev \
    libpng-dev \
    vips-dev \
    git

# Yarn is provided via Corepack on Node 22+ images
RUN corepack enable

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

WORKDIR /opt/

ARG STRAPI_VERSION=5.56.0

# Create a new Strapi project
RUN npx create-strapi-app@${STRAPI_VERSION} app \
    --quickstart \
    --no-run \
    --skip-cloud

WORKDIR /opt/app

# Install PostgreSQL driver (pg@8.x is required for Node 22+)
RUN npm install pg --save --ignore-scripts

# Build the admin panel
RUN npm run build

# Production stage
FROM node:22-alpine

# Install runtime dependencies
RUN apk add --no-cache vips-dev

RUN corepack enable

ENV NODE_ENV=production

WORKDIR /opt/app

# Copy built application from build stage
COPY --from=build /opt/app ./

# Change ownership to node user
RUN chown -R node:node /opt/app

USER node

EXPOSE 1337

CMD ["yarn", "start"]
