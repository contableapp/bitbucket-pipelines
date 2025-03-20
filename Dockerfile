FROM atlassian/default-image:4

RUN apt update && \
    apt install -y python3-pip build-essential libssl-dev libffi-dev python3-dev && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install awscli fabric boto3

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -L -o /usr/local/bin/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.30/aws-iam-authenticator_0.6.30_linux_amd64; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -L -o /usr/local/bin/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.30/aws-iam-authenticator_0.6.30_linux_arm64; \
    fi && \
    chmod +x /usr/local/bin/aws-iam-authenticator

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.30.10/bin/linux/amd64/kubectl; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.30.10/bin/linux/arm64/kubectl; \
    fi && \
    chmod +x /usr/local/bin/kubectl

RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh  | bash

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -LJO https://github.com/devshawn/kafka-gitops/releases/download/0.2.15/kafka-gitops.zip && \
        unzip kafka-gitops.zip && \
        mv kafka-gitops /usr/local/bin && \
        chmod +x /usr/local/bin/kafka-gitops && \
        rm kafka-gitops.zip; \
    fi




