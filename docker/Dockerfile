# Use precompiled centraldatabased binary from existing centraldatabased image
# (Alternatively, building from source requires Ubuntu 20.04 due to Boost 1.70 / GCC 11 incompatibilities)
FROM centraldatabased:latest AS binary-source

FROM ubuntu:22.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 libevent-2.1-7 libssl3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=binary-source /usr/local/bin/centraldatabased /usr/local/bin/centraldatabased
COPY c7-minerd.sh /usr/local/bin/c7-minerd
COPY scripts/check-blocks.sh /usr/local/bin/check-blocks
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/centraldatabased /usr/local/bin/c7-minerd /usr/local/bin/check-blocks /usr/local/bin/entrypoint.sh && \
    useradd --system --create-home --home-dir /home/centraldatabase centraldatabase

USER centraldatabase
WORKDIR /home/centraldatabase

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["c7-minerd"]
