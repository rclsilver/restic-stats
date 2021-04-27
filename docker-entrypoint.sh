#!/bin/sh

if [ ! -z "${TIMEZONE}" ]; then
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
fi

PRIVATE_KEY=$(ls -1 /root/.ssh/id_* | grep -vE '\.pub$')

if [ -z "${PRIVATE_KEY}" ]; then
    echo "No private key provided" >&2
    exit 1
fi

if [ $(echo ${PRIVATE_KEY} | wc -l) -gt 1 ]; then
    echo "More than one private key provided" >&2
    exit 1
fi

if [ -z "${SFTP_USERNAME}" ]; then
    echo "Environment variable 'SFTP_USERNAME' not provided" >&2
    exit 1
fi

if [ -z "${SFTP_HOSTNAME}" ]; then
    echo "Environment variable 'SFTP_HOSTNAME' not provided" >&2
    exit 1
fi

if [ -z "${INFLUXDB_HOST}" ]; then
    echo "Environment variable 'INFLUXDB_HOST' not provided" >&2
    exit 1
fi

if [ -z "${INFLUXDB_PORT}" ]; then
    echo "Environment variable 'INFLUXDB_PORT' not provided" >&2
    exit 1
fi

if [ -z "${INFLUXDB_USER}" ]; then
    echo "Environment variable 'INFLUXDB_USER' not provided. Using anonymous access" >&2
fi

if [ -z "${INFLUXDB_PASS}" ]; then
    echo "Environment variable 'INFLUXDB_PASS' not provided. Using anonymous access" >&2
fi

if [ -z "${RESTIC_DIRECTORY}" ]; then
    RESTIC_DIRECTORY="."
fi

cat <<EOF > /root/.ssh/config
Host restic
        User ${SFTP_USERNAME}
        HostName ${SFTP_HOSTNAME}
        IdentityFile ${PRIVATE_KEY}
        StrictHostKeyChecking no
EOF

function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

function get_used_bytes() {
    ssh restic du -sb "${RESTIC_DIRECTORY}" | awk '{ print $1 }' 2>/dev/null
}

function get_snapshots_count() {
    restic snapshots --json | jq '. | length'
}

function push_metric() {
    local name=${1}
    local value=${2}
    local timestamp=$(($(date +%s) * 1000000000))
    local url="http://${INFLUXDB_HOST}:${INFLUXDB_PORT}/write?db=${INFLUXDB_BASE}&precision=ns"
    local payload="${name} value=${value} ${timestamp}"
    local authent="${INFLUXDB_USER}:${INFLUXDB_PASS}"

    if [ "${authent}" != ":" ]; then
        authent="--user ${authent}"
    else
        authent=""
    fi

    http_code=$(curl -so /dev/null -w "%{http_code}" -A "restic-stats" ${authent} -X POST "${url}" -d "${payload}")
    r=$?

    if [ $r -ne 0 ]; then
        return 1
    fi

    if [ "${http_code}" != "204" ]; then
        return 1
    fi

    return 0
}

export RESTIC_PASSWORD_FILE=/root/.restic/password
export RESTIC_REPOSITORY=sftp:restic:.restic

USED_LAST_CHECK=-1
SNAPSHOTS_LAST_CHECK=-1

while [ 1 ]; do
    HOUR=$(date +%H)

    if [ ${HOUR} -ne ${USED_LAST_CHECK} ]; then
        USED_BYTES=$(get_used_bytes)
        R=$?

        if [ $R -eq 0 ]; then
            log "We are now using ${USED_BYTES} bytes on repository"

            push_metric restic_used_bytes ${USED_BYTES}
            R=$?

            if [ $R -eq 0 ]; then
                USED_LAST_CHECK=${HOUR}
            fi
        fi
    fi

    if [ ${HOUR} -ne ${SNAPSHOTS_LAST_CHECK} ]; then
        SNAPSHOTS_COUNT=$(get_snapshots_count)
        R=$?

        if [ $R -eq 0 ]; then
            log "We currently have ${SNAPSHOTS_COUNT} snapshots on the repository"

            push_metric restic_snapshots ${SNAPSHOTS_COUNT}
            R=$?

            if [ $R -eq 0 ]; then
                SNAPSHOTS_LAST_CHECK=${HOUR}
            fi
        fi
    fi

    sleep 60
done
