FROM alpine:3
RUN apk add --no-cache libc6-compat
RUN apk add --no-cache prometheus-node-exporter

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /local
ENTRYPOINT ["/entrypoint.sh"]
