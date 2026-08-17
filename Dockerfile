# Builds the RelaySend signaling server directly from this repository.
FROM rust:1.97-bookworm AS builder

ARG LOCAL_SEND_REF=af3aad33c965defc39ecff8d9a4396a851ce3cc1
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init localsend \
    && git -C localsend remote add origin https://github.com/LocalSend/LocalSend.git \
    && git -C localsend fetch --depth 1 origin "$LOCAL_SEND_REF" \
    && git -C localsend checkout FETCH_HEAD

COPY relay.patch /src/relay.patch
RUN cd localsend && git apply /src/relay.patch

WORKDIR /src/localsend
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/localsend/target \
    cargo build --release -p server \
    && cp target/release/server /server-bin

FROM debian:bookworm-slim AS runtime

RUN mkdir -p /data/shares

COPY --from=builder /server-bin /server

ENV SHARE_DATA_DIR=/data/shares
EXPOSE 3000
ENTRYPOINT ["/server"]
