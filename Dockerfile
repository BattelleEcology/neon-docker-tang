
FROM alpine:3.22.0 AS builder
# Dependabot does not support build args in a FROM. Need to duplicate the container version two places.
# ARG ALPINEVERSION=3.14.2

# ARG JOSE_COMMIT_SHA=145c41a4ec70c15f6f8aa12a915e16cb60f0991f
# ARG TANG_COMMIT_SHA=8affe3580c97280a8da31514d47c4ac4981992ec
ARG JOSE_COMMIT_SHA=v14
ARG TANG_COMMIT_SHA=v15

RUN apk add --no-cache --update \
    bash \
    g++ gawk git gmp gzip \
    http-parser-dev \
    isl-dev \
    jansson-dev \
    meson mpc1-dev mpfr-dev musl-dev \
    ninja \
    openssl-dev \
    tar \
    zlib-dev

RUN git clone https://github.com/latchset/jose.git \
 && cd jose \
 && git checkout ${JOSE_COMMIT_SHA} \
 && mkdir build \
 && cd build \
 && meson .. --prefix=/usr/local \
 && ninja install \
 && mkdir /patches

RUN git clone https://github.com/latchset/tang.git \
 && cd tang \
 && git checkout ${TANG_COMMIT_SHA} \
 && mkdir build \
 && cd build \
 && meson .. --prefix=/usr/local \
 && ninja install

FROM alpine:3.22.0

COPY --from=builder \
     /usr/local/bin/jose \
     /usr/local/bin/jose
COPY --from=builder \
     /usr/local/lib/libjose.so.0  \
     /usr/local/lib/libjose.so.0
COPY --from=builder \
     /usr/local/lib/libjose.so.0.0.0 \
     /usr/local/lib/libjose.so.0.0.0

COPY --from=builder \
     /usr/local/libexec/tangd \
     /usr/local/bin/tangd
COPY --from=builder \
     /usr/local/libexec/tangd-keygen \
     /usr/local/bin/tangd-keygen

RUN apk add --no-cache --update \
        bash \
        http-parser \
        jansson \
        openssl \
        socat \
        zlib

EXPOSE 8080
# VOLUME [ "/db" ]

CMD [ "socat", "tcp-l:8080,reuseaddr,fork", "exec:'tangd /db'" ]

# HEALTHCHECK --start-period=5s --interval=30s --timeout=5s --retries=3 \
#         CMD ["wget", "--tries", "5", "-qSO", "/dev/null",  "http://localhost:8080/adv"]