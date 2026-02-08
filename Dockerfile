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

COPY mix.exs mix.lock ./
COPY apps/streamflix_core/mix.exs apps/streamflix_core/
COPY apps/streamflix_accounts/mix.exs apps/streamflix_accounts/
COPY apps/streamflix_web/mix.exs apps/streamflix_web/

RUN mix deps.get --only prod

COPY config config
COPY apps apps

RUN mix compile

WORKDIR /app/apps/streamflix_web
RUN mix assets.deploy
WORKDIR /app

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
    postgresql-client \
    curl

WORKDIR /app

COPY --from=build /app/_build/prod/rel/streamflix ./

ENV HOME=/app
ENV MIX_ENV=prod

RUN addgroup -S app && adduser -S app -G app
RUN chown -R app:app /app
USER app

EXPOSE 4000

# App serves HTTP on / ; no /health endpoint by default
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:4000/ || exit 1

CMD ["bin/streamflix", "start"]
