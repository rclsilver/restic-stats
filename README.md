# restic-stats

## Running in docker

```bash
docker run --rm -it \
    -v $(pwd)/data/id_ed25519.restic:/root/.ssh/id_ed25519 \
    -v $(pwd)/data/id_ed25519.restic.pub:/root/.ssh/id_ed25519.restic.pub \
    -v $(pwd)/data/password:/root/.restic/password \
    -e SFTP_USERNAME=remote-user \
    -e SFTP_HOSTNAME=remote-ssh-server \
    -e RESTIC_DIRECTORY=restic-data \
    -e INFLUXDB_USER=metrics \
    -e INFLUXDB_PASS=secret-password \
    -e INFLUXDB_HOST=172.17.0.1 \
    -e INFLUXDB_PORT=8086 \
    -e INFLUXDB_BASE=metrics \
    -e TIMEZONE=Europe/Paris \
    rclsilver/restic-stats
```

## Known limitations

`restic-stats` is currently working only with SFTP repositories and InfluxDB.
