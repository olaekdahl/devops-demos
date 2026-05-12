# Tiny base for a fast-building Docker action.
FROM alpine:3.20

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
