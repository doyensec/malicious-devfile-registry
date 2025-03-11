FROM registry.access.redhat.com/ubi8/go-toolset:1.18 AS builder
USER root
RUN curl -sL -O https://github.com/mikefarah/yq/releases/download/v4.9.5/yq_linux_amd64 -o /usr/local/bin/yq && mv ./yq_linux_amd64 /usr/local/bin/yq && chmod +x /usr/local/bin/yq
COPY . /registry
COPY . /build
USER 1001
FROM quay.io/devfile/devfile-index-base:next
COPY ./index.json /index.json
COPY ./stacks /stacks
COPY . /registry
COPY . /build
