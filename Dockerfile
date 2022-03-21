FROM python:3.8-alpine as builder

RUN apk add --no-cache \
    linux-headers \
    tcpdump \
    build-base \
    ebtables \
    make \
    git && \
    apk upgrade --no-cache

WORKDIR /kube-hunter
COPY setup.py setup.cfg Makefile ./
RUN make deps

COPY . .
RUN make install

FROM registry.access.redhat.com/ubi8/ubi:8.5-236.1647448331

LABEL name="kube-hunter" \
      maintainer="support@cloudcasa.io" \
      vendor="Catalogic Software" \
      version="3.0.0" \
      release="3.0.0" \
      summary="Image contains agent to perform kubernetes cluster scanning operations" \
      description="Kubernetes backup, restore and scanning"

RUN yum -y update \
 && yum upgrade \
 && yum -y install python3.8 \
 && curl http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/tcpdump-4.9.3-1.el8.x86_64.rpm -o tcpdump-4.9.3-1.el8.x86_64.rpm \
 && dnf install shadow-utils -y \
 && dnf install libpcap-14:1.9.1-5.el8.x86_64 -y \
 && rpm -i tcpdump-4.9.3-1.el8.x86_64.rpm \
 && rm tcpdump-4.9.3-1.el8.x86_64.rpm \
 && cp /usr/bin/python3.8 /usr/local/bin/python \
 && curl https://forensics.cert.org/centos/cert/7/x86_64/musl-filesystem-1.2.1-1.el7.x86_64.rpm -o musl-filesystem-1.2.1-1.el7.x86_64.rpm \
 && rpm -Uvh musl-filesystem-1.2.1-1.el7.x86_64.rpm \
 && curl https://forensics.cert.org/centos/cert/7/x86_64/musl-libc-1.2.1-1.el7.x86_64.rpm -o musl-libc-1.2.1-1.el7.x86_64.rpm \
 && rpm -Uvh musl-libc-1.2.1-1.el7.x86_64.rpm \
 && yum install gcc glibc glibc-common gd gd-devel -y \
 && yum install make -y \ 
 && curl https://musl.libc.org/releases/musl-1.2.2.tar.gz -o musl-1.2.2.tar.gz \
 && tar -xvf musl-1.2.2.tar.gz && cd musl-1.2.2 \
 && ./configure && make && make install && cd - \
 && ln -s /usr/lib64/libc.so.6 /usr/lib64/libc.musl-x86_64.so.1 \
 && dnf install iptables -y \
 && curl https://vault.centos.org/centos/8/BaseOS/x86_64/os/Packages/iptables-ebtables-1.8.4-20.el8.x86_64.rpm -o iptables-ebtables-1.8.4-20.el8.x86_64.rpm \
 && rpm -Uvh iptables-ebtables-1.8.4-20.el8.x86_64.rpm 

COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/lib/python3.8/site-packages
COPY --from=builder /usr/local/bin/kube-hunter /usr/local/bin/kube-hunter
COPY --from=builder /usr/local/bin/kube-hunter /usr/local/sbin/kube-hunter

RUN groupadd -r nogroup && mkdir /licenses
COPY LICENSE /licenses
USER nobody:nogroup

ENTRYPOINT ["/usr/local/sbin/kube-hunter"]
