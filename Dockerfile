# ============================================
# JOBSCELIS - Dockerfile
# Elixir 1.17 / OTP 27
# ============================================

FROM elixir:1.17-otp-27-alpine AS base

RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    postgresql-client \
    curl

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

# ============================================
# DEVELOPMENT
# ============================================

FROM base AS dev

ENV MIX_ENV=dev

COPY mix.exs mix.lock ./
COPY apps/streamflix_core/mix.exs apps/streamflix_core/
COPY apps/streamflix_accounts/mix.exs apps/streamflix_accounts/
COPY apps/streamflix_web/mix.exs apps/streamflix_web/

RUN mix deps.get

COPY . .

RUN mix compile

EXPOSE 4000

CMD ["mix", "phx.server"]

# ============================================
# PRODUCTION BUILD
# ============================================

FROM base AS build

ENV MIX_ENV=prod

# 1. Copy only mix files — cached until mix.lock changes
COPY mix.exs mix.lock ./
COPY apps/streamflix_core/mix.exs apps/streamflix_core/
COPY apps/streamflix_accounts/mix.exs apps/streamflix_accounts/
COPY apps/streamflix_web/mix.exs apps/streamflix_web/

# 2. Download and compile deps — cached layer
RUN mix deps.get --only prod
RUN mix deps.compile

# 3. Copy config — changes less frequently than app code
COPY config config

# 4. Copy app code — changes most frequently
COPY apps apps

# 5. Compile only app code (deps already compiled above)
RUN mix compile

# 6. Build assets
WORKDIR /app/apps/streamflix_web
RUN mix assets.deploy
WORKDIR /app

# 7. Create release
RUN mix release

# ============================================
# PRODUCTION RUNTIME
# ============================================
# Usar la MISMA base que el build (elixir:...-alpine) para que OpenSSL y las
# libs con las que se compiló Erlang coincidan. Con alpine:3.20 suelto sale:
# "EVP_MD_CTX_get_size_ex: symbol not found" (incompatibilidad crypto/OpenSSL).

FROM elixir:1.17-otp-27-alpine AS prod

RUN apk add --no-cache \
    libstdc++ \
    ca-certificates \
    postgresql-client \
    curl

WORKDIR /app

COPY --from=build /app/_build/prod/rel/streamflix ./

ENV HOME=/app
ENV MIX_ENV=prod

RUN addgroup -S app && adduser -S app -G app && \
    chown -R app:app /app
USER app

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

CMD bin/streamflix eval "StreamflixCore.Release.migrate()" && bin/streamflix start
