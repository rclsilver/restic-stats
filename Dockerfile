FROM restic/restic:0.9.4

RUN apk add --update --no-cache jq curl tzdata

COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
