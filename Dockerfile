# ============================================
# STREAMFLIX DOCKERFILE
# Using latest Elixir 1.17 with Erlang/OTP 27
# ============================================

FROM elixir:1.17-otp-27-alpine AS base

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    postgresql-client \
    inotify-tools \
    curl

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# ============================================
# DEVELOPMENT STAGE
# ============================================

FROM base AS dev

# Set environment
ENV MIX_ENV=dev

# Copy mix files
COPY mix.exs mix.lock ./
COPY apps/streamflix_core/mix.exs apps/streamflix_core/
COPY apps/streamflix_accounts/mix.exs apps/streamflix_accounts/
COPY apps/streamflix_catalog/mix.exs apps/streamflix_catalog/
COPY apps/streamflix_streaming/mix.exs apps/streamflix_streaming/
COPY apps/streamflix_cdn/mix.exs apps/streamflix_cdn/
COPY apps/streamflix_web/mix.exs apps/streamflix_web/

# Get dependencies
RUN mix deps.get

# Copy application code
COPY . .

# Compile
RUN mix compile

# Expose port
EXPOSE 4000

# Start command
CMD ["mix", "phx.server"]

# ============================================
# PRODUCTION BUILD STAGE
# ============================================

FROM base AS build

ENV MIX_ENV=prod

# Copy mix files
COPY mix.exs mix.lock ./
COPY apps/streamflix_core/mix.exs apps/streamflix_core/
COPY apps/streamflix_accounts/mix.exs apps/streamflix_accounts/
COPY apps/streamflix_catalog/mix.exs apps/streamflix_catalog/
COPY apps/streamflix_streaming/mix.exs apps/streamflix_streaming/
COPY apps/streamflix_cdn/mix.exs apps/streamflix_cdn/
COPY apps/streamflix_web/mix.exs apps/streamflix_web/

# Get dependencies
RUN mix deps.get --only prod

# Copy config
COPY config config

# Copy application code
COPY apps apps

# Compile
RUN mix compile

# Build assets
WORKDIR /app/apps/streamflix_web
RUN mix assets.deploy
WORKDIR /app

# Build release
RUN mix release

# ============================================
# PRODUCTION RUNTIME STAGE
# ============================================

FROM alpine:3.20 AS prod

RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    postgresql-client \
    curl

WORKDIR /app

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/streamflix ./

# Set environment
ENV HOME=/app
ENV MIX_ENV=prod

# Create non-root user
RUN addgroup -S streamflix && adduser -S streamflix -G streamflix
RUN chown -R streamflix:streamflix /app
USER streamflix

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Start command
CMD ["bin/streamflix", "start"]
