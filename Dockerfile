FROM atlassian/default-image:2

RUN apt-get update && \
    apt-get install -y python3-pip build-essential libssl-dev libffi-dev python3-dev && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install awscli

RUN curl -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator && \
    chmod +x /usr/local/bin/aws-iam-authenticator

RUN curl -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh  | bash

RUN curl -LJO https://github.com/devshawn/kafka-gitops/releases/download/0.2.5/kafka-gitops.zip && unzip kafka-gitops.zip && \
    mv kafka-gitops /usr/local/bin && chmod +x /usr/local/bin/kafka-gitops && rm kafka-gitops.zip

RUN pip3 install fabric