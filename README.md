# Custom Bitbucket Pipelines image

Multi-architecture Docker image used as the `image:` for the Bitbucket Pipelines of every Contable service. Bundles the tooling that pipelines invoke directly so individual `bitbucket-pipelines.yml` files don't need to install anything before running their commands.

Built and pushed manually. Multi-arch via `docker buildx` + QEMU.

## What's inside

| Tool | Version | Purpose |
|------|---------|---------|
| `atlassian/default-image` | `5.20250519` | Base. Brings git, jq, curl, Node 18 (via nvm), Java JRE, build tools |
| `awscli` | latest pip | ECR login, EKS describe, ad-hoc AWS commands |
| `aws-iam-authenticator` | `v0.7.13` | IAM → K8s user mapping for EKS auth |
| `kubectl` | `v1.33.11` | K8s client. Pinned within +/-1 minor of EKS server version |
| `kustomize` | `v5.8.1` | Manifest builder for `kubectl apply -k` |
| `helm` | `v4.1.4` | Chart-based deploys (third-party tools, observability stack) |
| `trivy` | `v0.70.0` | Vulnerability scanner (used by the `Vulnerability scan` step) |
| `yq` | `v4.53.2` | YAML processor for manifest manipulation |
| `kafka-gitops` | `0.2.15` (x86_64 only) | Kafka topic GitOps. Unmaintained upstream — kept until migrated |
| `fabric`, `boto3` | latest pip | Python tooling for legacy deploy scripts |

OS security patches are applied at build time via `apt-get upgrade -y` on top of the Atlassian base, so each rebuild picks up CVE fixes between Atlassian's own rebuilds.

## Tagging convention

Each push gets two tags:

- `latest` — mutable, always points at the most recent build.
- `YYYYMMDD` — immutable date stamp (e.g. `20260427`). Use this when a service pipeline wants reproducibility (`image: contable/bitbucket-pipelines:20260427`).

Service pipelines today use `image: contable/bitbucket-pipelines` (implicit `:latest`). Pinning to a date stamp is opt-in per service.

## Build

Multi-arch image (linux/arm64 + linux/amd64) via `docker buildx`:

```bash
DATE_TAG=$(date -u +%Y%m%d)

docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --no-cache \
  -t contable/bitbucket-pipelines:latest \
  -t contable/bitbucket-pipelines:${DATE_TAG} \
  --push \
  .
```

The `--push` flag has buildx push directly to Docker Hub during the build (no separate `docker push` step needed for multi-arch — the manifest list is created in-place).

If you need to inspect locally without pushing first, drop `--push` and add `--load`, but `--load` doesn't work with multi-platform builds — single-arch only when loading.

## Verify

After the push completes, smoke-test the published image:

```bash
docker pull contable/bitbucket-pipelines:latest

docker run --rm contable/bitbucket-pipelines:latest sh -c '
  aws --version &&
  kubectl version --client &&
  kustomize version &&
  helm version --short &&
  trivy --version | head -1 &&
  yq --version &&
  aws-iam-authenticator version
'
```

Each tool should print its version. The Dockerfile already runs the same checks at build time as a sanity check, so a broken release URL fails the build instead of producing a silently-broken image.

## Troubleshooting

If the build fails for a specific architecture, it's usually QEMU emulation needing a reset:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
```

Then re-run `docker buildx build`.

If `--push` fails with auth errors, run `docker login` first (Docker Hub credentials).

## Bumping a tool

1. Edit the Dockerfile, change the version in the corresponding `RUN` block.
2. Update the version table in this README.
3. Build + push following the commands above (date stamp will be the build date).
4. Verify with the smoke-test command.
5. Commit + push the Dockerfile + README change.

For `kubectl` specifically: bump in lockstep with EKS control plane upgrades. Stay within +/-1 minor of the server version (currently `v1.32.x` server → `v1.33.x` client is fine).
