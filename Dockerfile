# Bitbucket Pipelines base image for Contable services.
#
# Tagging convention: each push gets two tags — `latest` (mutable,
# always points at the most recent build) and a date stamp like
# `20260427` (immutable, for pinning when reproducibility matters).
#
# Built multi-arch (linux/amd64 + linux/arm64) via `docker buildx`.
# See README for the build/push commands.

FROM atlassian/default-image:5.20250519

# OS security patches on top of the base image (Ubuntu 22.04 under
# the hood). Atlassian rebuilds the base periodically; this `apt
# upgrade` ensures we pick up CVE fixes between their rebuilds and
# our own.
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        python3-pip build-essential libssl-dev libffi-dev python3-dev unzip && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Python tooling used across pipelines: awscli for ECR login + EKS
# describe; fabric for older deploy scripts that haven't migrated;
# boto3 for ad-hoc AWS scripting.
RUN pip3 install --no-cache-dir awscli fabric boto3

# aws-iam-authenticator: maps IAM identities to Kubernetes users when
# kubectl talks to EKS.
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_TAG=amd64; \
    elif [ "$ARCH" = "aarch64" ]; then ARCH_TAG=arm64; \
    fi && \
    curl -fsSL -o /usr/local/bin/aws-iam-authenticator \
        "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.13/aws-iam-authenticator_0.7.13_linux_${ARCH_TAG}" && \
    chmod +x /usr/local/bin/aws-iam-authenticator

# kubectl: pinned within +/-1 minor of the EKS server version. Bump
# this in lockstep when the EKS control plane is upgraded.
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_TAG=amd64; \
    elif [ "$ARCH" = "aarch64" ]; then ARCH_TAG=arm64; \
    fi && \
    curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/v1.33.11/bin/linux/${ARCH_TAG}/kubectl" && \
    chmod +x /usr/local/bin/kubectl

# kustomize: pinned version (the upstream install script tracks
# latest, which can drift across rebuilds and break manifests).
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_TAG=amd64; \
    elif [ "$ARCH" = "aarch64" ]; then ARCH_TAG=arm64; \
    fi && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.8.1/kustomize_v5.8.1_linux_${ARCH_TAG}.tar.gz" \
        | tar -xz -C /usr/local/bin && \
    chmod +x /usr/local/bin/kustomize

# helm: used by pipelines that deploy Helm releases (third-party
# tools, observability stack, anything not on the kubectl-set-image
# happy path).
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_TAG=amd64; \
    elif [ "$ARCH" = "aarch64" ]; then ARCH_TAG=arm64; \
    fi && \
    curl -fsSL "https://get.helm.sh/helm-v4.1.4-linux-${ARCH_TAG}.tar.gz" \
        | tar -xz -C /tmp && \
    mv "/tmp/linux-${ARCH_TAG}/helm" /usr/local/bin/helm && \
    rm -rf "/tmp/linux-${ARCH_TAG}" && \
    chmod +x /usr/local/bin/helm

# Trivy: vulnerability scanner for the security-scan pipeline step.
# The official install.sh auto-detects arch.
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
        | sh -s -- -b /usr/local/bin v0.70.0

# yq: YAML processor for pipelines that manipulate manifest fragments
# (ingress patches, kustomize overlays, etc.).
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_TAG=amd64; \
    elif [ "$ARCH" = "aarch64" ]; then ARCH_TAG=arm64; \
    fi && \
    curl -fsSL -o /usr/local/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/v4.53.2/yq_linux_${ARCH_TAG}" && \
    chmod +x /usr/local/bin/yq

# kafka-gitops: x86_64 only. The upstream repo is unmaintained but
# the binary still works for our existing kafka topic-management
# pipelines. Kept until those pipelines are migrated to a different
# tool (Strimzi KafkaTopic CRDs are the likely successor).
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -fsSLO https://github.com/devshawn/kafka-gitops/releases/download/0.2.15/kafka-gitops.zip && \
        unzip kafka-gitops.zip && \
        mv kafka-gitops /usr/local/bin && \
        chmod +x /usr/local/bin/kafka-gitops && \
        rm kafka-gitops.zip; \
    fi

# Quick sanity check at build time so a broken release URL fails
# the build instead of producing a silently-broken image.
RUN aws --version && \
    kubectl version --client && \
    kustomize version && \
    helm version --short && \
    trivy --version | head -1 && \
    yq --version && \
    aws-iam-authenticator version
