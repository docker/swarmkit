FROM golang:1.6-alpine

RUN set -ex \
    && apk add --no-cache --virtual .build-deps git make

COPY . /go/src/github.com/docker/swarm-v2
WORKDIR /go/src/github.com/docker/swarm-v2

RUN set -ex \
    && make install
