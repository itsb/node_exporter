# node_exporter with a PCI class include filter

This fork of [Prometheus node_exporter](https://github.com/prometheus/node_exporter)
v1.12.1 adds the opt-in `--collector.pcidevice.class-include` flag. The default
includes all PCI devices, preserving upstream behavior. The Apache-2.0 license,
NOTICE, and upstream attribution are preserved.

## Container image

Published releases use `ghcr.io/itsb/node-exporter:1.12.1-pci.2` and support
**Linux amd64 and arm64**. Use the release workflow's recorded manifest digest
for a fixed deployment. SHA tags also identify the source commit. There is no
automatically moving `latest` tag. Each new release needs a new `-pci.N` version.

```sh
docker pull ghcr.io/itsb/node-exporter:1.12.1-pci.2

docker run --rm --network=host --pid=host \
  -v /:/host:ro,rslave \
  ghcr.io/itsb/node-exporter:1.12.1-pci.2 \
  --path.rootfs=/host --path.procfs=/host/proc --path.sysfs=/host/sys \
  --collector.pcidevice \
  '--collector.pcidevice.class-include=^0x03[0-9a-f]{4}$'
```

This example listens on the normal exporter port 9100. Choose an available
`--web.listen-address` when running alongside an existing exporter.

The filter retains all display subclasses, including VGA, 3D, and other display
controllers. Selection is independent of vendor and `pci.ids`; separate audio
functions are excluded. All per-device PCI metric families are filtered.
Sysfs enumeration still reads every PCI device. A host with no matching classes
emits no per-device PCI metrics and reports a successful collector scrape.

Optional name resolution requires a readable host IDs file, for example:

```text
--collector.pcidevice.names
--collector.pcidevice.idsfile=/host/usr/share/misc/pci.ids
```

The host's path may instead be `/usr/share/hwdata/pci.ids`. With a missing IDs
file, ID labels and filtering still work; name labels fall back to IDs.

## GitHub Actions publishing

[Patched container](.github/workflows/publish-container.yml) runs dependency
tidiness checks, upstream race tests, vet, end-to-end tests, and image smoke/filter checks on native amd64
and arm64 GitHub runners. Only the tested image archives are uploaded and later
published. Pull requests and branch pushes test without publishing.

To publish, first push the tested source to `pci-release`, then push a version
tag such as `v1.12.1-pci.2` pointing to that commit. Tag runs repeat the checks.
The publishing job uses the repository's short-lived `GITHUB_TOKEN`, with
`packages: write` only on that job. It publishes exclusively to this fork's GHCR
namespace, links the package to this source repository, verifies both platforms,
and records the digest in the workflow summary. Existing release tags are not
overwritten by the workflow. The upstream publishing jobs are restricted to the
upstream repository.

GHCR packages are initially private, even when source is public. To permit pulls
without credentials, change this package to public in
[package settings](https://github.com/users/itsb/packages/container/node-exporter/settings).
Network access to GHCR is still required from each deployment host. The release
workflow publishes an image; it does not change or restart any deployment.
