# Custom Bitbucket Pipeline Docker Image

This guide explains how to create, publish, and troubleshoot 
a multi-architecture modified Bitbucket Pipelines image Docker image. 
By using Docker Buildx, we can build images that support multiple architectures, 
such as `linux/arm64` and `linux/amd64`.


## Build

To build a multi-architecture Docker image, run the following command:

```shell
docker buildx build --platform linux/arm64,linux/amd64 --no-cache -t contable/bitbucket-pipelines:latest .
```

Once the image has been built, you can push it to the Docker registry using:

```
docker push contable/bitbucket-pipelines:latest
```

## Troubleshooting

In case the build process for a specific architecture fails,
it may be due to the misconfiguration of QEMU
(a virtualization tool used for emulating non-native architectures). 
In such cases, QEMU needs to be reset and properly configured.

```shell
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes -c yes
```