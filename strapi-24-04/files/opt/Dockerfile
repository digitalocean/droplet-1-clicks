# Multi-stage build for Strapi
FROM node:20-alpine AS build

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

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

WORKDIR /opt/

# Create a new Strapi project
RUN npx create-strapi-app@5.0.0 app \
    --quickstart \
    --no-run \
    --skip-cloud

WORKDIR /opt/app

# Install PostgreSQL driver
RUN npm install pg --save

# Build the admin panel
RUN npm run build

# Production stage
FROM node:20-alpine

# Install runtime dependencies
RUN apk add --no-cache vips-dev

ENV NODE_ENV=production

WORKDIR /opt/app

# Copy built application from build stage
COPY --from=build /opt/app ./

# Change ownership to node user
RUN chown -R node:node /opt/app

USER node

EXPOSE 1337

CMD ["yarn", "start"]
