FROM atlassian/default-image:4

RUN apt-get update && \
    apt-get install -y python3-pip build-essential libssl-dev libffi-dev python3-dev && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install awscli

RUN curl -L -o /usr/local/bin/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.6.30/aws-iam-authenticator_0.6.30_linux_amd64 && \
    chmod +x /usr/local/bin/aws-iam-authenticator

RUN curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/v1.30.10/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh  | bash

RUN curl -LJO https://github.com/devshawn/kafka-gitops/releases/download/0.2.15/kafka-gitops.zip && unzip kafka-gitops.zip && \
    mv kafka-gitops /usr/local/bin && chmod +x /usr/local/bin/kafka-gitops && rm kafka-gitops.zip

RUN pip3 install fabric