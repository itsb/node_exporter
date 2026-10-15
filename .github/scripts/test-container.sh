#!/usr/bin/env bash
set -euo pipefail

image=${1:?Usage: test-container.sh IMAGE}
tmpdir=$(mktemp -d)
container_id=''

cleanup() {
    if [[ -n "$container_id" ]]; then
        docker rm -f "$container_id" >/dev/null
    fi
    rm -rf "$tmpdir"
}
trap cleanup EXIT

scrape() {
    container_id=$(docker run --rm -d -p 127.0.0.1::9100 \
        -v "$PWD/collector/fixtures:/fixtures:ro" "$image" "$@")
    port=$(docker inspect --format '{{(index (index .NetworkSettings.Ports "9100/tcp") 0).HostPort}}' "$container_id")
    for attempt in {1..30}; do
        if curl --fail --silent --max-time 5 "http://127.0.0.1:$port/metrics" > "$tmpdir/metrics"; then
            return
        fi
        sleep 1
    done
    docker logs "$container_id"
    return 1
}

stop() {
    docker rm -f "$container_id" >/dev/null
    container_id=''
}

# Exercise the image's default entrypoint and collectors.
scrape
awk '/^node_uname_info\{/ { found=1 } END { exit !found }' "$tmpdir/metrics"
stop

# Fixture devices are storage, bridge, and network classes; none is a display.
flags=(--collector.disable-defaults --collector.uname --collector.pcidevice
    --path.sysfs=/fixtures/sys --collector.pcidevice.names
    --collector.pcidevice.idsfile=/fixtures/pci.ids)
scrape "${flags[@]}"
awk '/^node_pcidevice_info\{/ { count++ } END { exit count != 3 }' "$tmpdir/metrics"
stop

scrape "${flags[@]}" '--collector.pcidevice.class-include=^0x03[0-9a-f]{4}$'
awk '/^node_pcidevice_/ { found=1 } END { exit found }' "$tmpdir/metrics"
awk '/^node_scrape_collector_success\{collector="pcidevice"\} 1$/ { found=1 } END { exit !found }' "$tmpdir/metrics"
awk '/^node_uname_info\{/ { found=1 } END { exit !found }' "$tmpdir/metrics"
stop

if docker run --rm "$image" --collector.pcidevice \
    '--collector.pcidevice.class-include=[' > "$tmpdir/invalid" 2>&1; then
    echo 'Malformed class include pattern unexpectedly succeeded' >&2
    exit 1
fi
awk '/invalid --collector.pcidevice.class-include/ { found=1 } END { exit !found }' "$tmpdir/invalid"
echo "Container checks passed: $image"
