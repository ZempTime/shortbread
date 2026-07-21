# syntax=docker/dockerfile:1.7

ARG RUBY_VERSION=3.4.10
ARG NODE_VERSION=24.18.0

FROM node:${NODE_VERSION}-bookworm-slim AS node

FROM debian:bookworm-slim AS anycable
ARG TARGETARCH
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y ca-certificates curl \
    && case "$TARGETARCH" in \
      arm64) ANYCABLE_URL="https://github.com/anycable/anycable/releases/download/v1.6.15/anycable-go-linux-arm64"; ANYCABLE_SHA256="b90323e526a712ad524e8a268e03bbf6b0df99a18525d8e55c34e286bf185427" ;; \
      amd64) ANYCABLE_URL="https://github.com/anycable/anycable/releases/download/v1.6.15/anycable-go-linux-amd64"; ANYCABLE_SHA256="d605a92046c01bc068d7afe7ba70a06b99735df2ec62fd656e08c20400620fcd" ;; \
      *) echo "unsupported container architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --silent --show-error "$ANYCABLE_URL" --output /usr/local/bin/anycable-go \
    && echo "$ANYCABLE_SHA256  /usr/local/bin/anycable-go" | sha256sum --check --strict \
    && chmod 0755 /usr/local/bin/anycable-go

FROM ruby:${RUBY_VERSION}-slim-bookworm AS build
ARG TARGETARCH
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y build-essential ca-certificates curl git libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && case "$TARGETARCH" in \
      arm64) AUBE_ARCHIVE="aube-v1.29.1-aarch64-unknown-linux-musl.tar.gz"; AUBE_SHA256="86496c2b78c8c23f7723954f7b668c38641b855243c1f6b0987766240fc680de" ;; \
      amd64) AUBE_ARCHIVE="aube-v1.29.1-x86_64-unknown-linux-musl.tar.gz"; AUBE_SHA256="9cc524b64b6f0506d2184b227c52e7aaa07ccd799715a1d23dbd9d3d88f334be" ;; \
      *) echo "unsupported container architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl --fail --location --silent --show-error "https://github.com/jdx/aube/releases/download/v1.29.1/$AUBE_ARCHIVE" --output "/tmp/$AUBE_ARCHIVE" \
    && echo "$AUBE_SHA256  /tmp/$AUBE_ARCHIVE" | sha256sum --check --strict \
    && tar -xzf "/tmp/$AUBE_ARCHIVE" -C /usr/local/bin aube \
    && rm "/tmp/$AUBE_ARCHIVE"

COPY --from=node /usr/local/ /usr/local/
WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install \
    && rm -rf /usr/local/bundle/ruby/*/cache /usr/local/bundle/ruby/*/bundler/gems/*/.git

COPY package.json aube-lock.yaml ./
RUN aube install --frozen-lockfile --reporter append-only

COPY . .
RUN aube run build \
    && bundle exec bootsnap precompile --gemfile app/ lib/ \
    && rm -rf node_modules

FROM ruby:${RUBY_VERSION}-slim-trixie AS runtime
ARG VCS_REF=unknown
LABEL org.opencontainers.image.source="https://github.com/ZempTime/shortbread" \
      org.opencontainers.image.revision="$VCS_REF" \
      org.opencontainers.image.title="Shortbread production candidate"

ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    PORT=3000 \
    PITCHFORK_HOST=0.0.0.0 \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    ANYCABLE_DISABLE_TELEMETRY=true \
    ANYCABLE_BROADCAST_ADAPTER=http \
    ANYCABLE_HOST=0.0.0.0 \
    ANYCABLE_HTTP_BROADCAST_PORT=8090 \
    ANYCABLE_PORT=8080

RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y ca-certificates libpq5 postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 shortbread \
    && useradd --uid 10001 --gid 10001 --create-home --home-dir /home/shortbread shortbread \
    && mkdir -p /app /app/log /app/tmp /var/lib/shortbread/blobs \
    && chown -R 10001:10001 /app /home/shortbread /var/lib/shortbread

COPY --from=anycable /usr/local/bin/anycable-go /usr/local/bin/anycable-go
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=10001:10001 /app /app

WORKDIR /app
USER 10001:10001
ENTRYPOINT ["bin/production"]
CMD ["web"]
