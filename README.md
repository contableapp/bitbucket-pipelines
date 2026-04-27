# Custom Bitbucket Pipelines image

Multi-architecture Docker image used as the `image:` for the Bitbucket Pipelines of every Contable service. Bundles the tooling that pipelines invoke directly so individual `bitbucket-pipelines.yml` files don't need to install anything before running their commands.

Built and pushed manually. Multi-arch via `docker buildx` + QEMU. Hosted on **Amazon ECR** (`829063853445.dkr.ecr.us-east-2.amazonaws.com/contable/bitbucket-pipelines`) — no Docker Hub rate limits, pulls stay inside AWS, same auth as the per-service ECR repos.

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

Each push gets two tags on ECR:

- `:latest` — mutable, always points at the most recent build.
- `:YYYYMMDD` — immutable date stamp (e.g. `:20260427`). Use this when a service pipeline wants reproducibility.

Service pipelines that want the always-fresh build use `:latest`. Pipelines that want a stable point-in-time pin use the date stamp.

A lifecycle policy on the ECR repository keeps the **last 10 images** and expires the rest, so the registry stays bounded.

## Using this image in a service `bitbucket-pipelines.yml`

```yaml
image:
  name: 829063853445.dkr.ecr.us-east-2.amazonaws.com/contable/bitbucket-pipelines:latest
  aws:
    access-key: $AWS_ACCESS_KEY_ID
    secret-key: $AWS_SECRET_ACCESS_KEY
```

The `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` repository (or workspace) variables in Bitbucket are the same ones that the rest of the pipeline already uses for `aws ecr get-login-password`, `aws eks update-kubeconfig`, etc. — no new secrets to set up.

To pin a specific build, replace `:latest` with the date stamp:

```yaml
image:
  name: 829063853445.dkr.ecr.us-east-2.amazonaws.com/contable/bitbucket-pipelines:20260427
  aws: ...
```

## Build

Multi-arch (linux/arm64 + linux/amd64) via `docker buildx`, pushing directly to ECR:

```bash
# 1. Authenticate Docker to ECR (token valid 12h)
aws ecr get-login-password --region us-east-2 --profile contable | \
  docker login --username AWS --password-stdin 829063853445.dkr.ecr.us-east-2.amazonaws.com

# 2. Build + push, tagging both `latest` and a date stamp
DATE_TAG=$(date -u +%Y%m%d)
ECR_URI=829063853445.dkr.ecr.us-east-2.amazonaws.com/contable/bitbucket-pipelines

docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --no-cache \
  -t "${ECR_URI}:latest" \
  -t "${ECR_URI}:${DATE_TAG}" \
  --push \
  .
```

The `--push` flag has buildx push directly to ECR during the build (no separate `docker push` step needed for multi-arch — the manifest list is created in-place).

If you need to inspect locally without pushing first, drop `--push` and add `--load`, but `--load` doesn't work with multi-platform builds — single-arch only when loading.

## Verify

After the push completes, smoke-test the pulled image:

```bash
ECR_URI=829063853445.dkr.ecr.us-east-2.amazonaws.com/contable/bitbucket-pipelines

aws ecr get-login-password --region us-east-2 --profile contable | \
  docker login --username AWS --password-stdin 829063853445.dkr.ecr.us-east-2.amazonaws.com

docker pull "${ECR_URI}:latest"

docker run --rm "${ECR_URI}:latest" sh -c '
  aws --version &&
  kubectl version --client &&
  kustomize version &&
  helm version --short &&
  trivy --version | head -1 &&
  yq --version &&
  aws-iam-authenticator version
'
```

Each tool should print its version. The Dockerfile also runs the same checks at build time as a sanity check, so a broken release URL fails the build instead of producing a silently-broken image.

## Troubleshooting

**QEMU emulation glitches** during arm64 build → reset and retry:

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
```

**`--push` fails with auth errors** → re-login to ECR (the token expires after 12 hours):

```bash
aws ecr get-login-password --region us-east-2 --profile contable | \
  docker login --username AWS --password-stdin 829063853445.dkr.ecr.us-east-2.amazonaws.com
```

**A service pipeline can't pull this image** with `Error pulling image: pull access denied` → confirm the service's `bitbucket-pipelines.yml` has the `image.aws.access-key` / `secret-key` block (see "Using this image" above) and that the corresponding repository variables exist.

## Bumping a tool

1. Edit the Dockerfile, change the version in the corresponding `RUN` block.
2. Update the version table in this README.
3. Build + push following the commands above (date stamp will be the build date).
4. Verify with the smoke-test command.
5. Commit + push the Dockerfile + README change.

For `kubectl` specifically: bump in lockstep with EKS control plane upgrades. Stay within +/-1 minor of the server version (currently `v1.32.x` server → `v1.33.x` client is fine).
