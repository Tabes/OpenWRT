FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    libncurses5-dev \
    gawk \
    git \
    subversion \
    libssl-dev \
    gettext \
    unzip \
    zlib1g-dev \
    file \
    python3 \
    python3-distutils \
    python3-setuptools \
    rsync \
    wget \
    curl \
    time \
    ccache \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /builder

# Verwende neuere OpenWRT Version die BPI-R4 unterstützt
RUN wget https://downloads.openwrt.org/snapshots/targets/mediatek/filogic/openwrt-imagebuilder-mediatek-filogic.Linux-x86_64.tar.xz && \
    tar -xf openwrt-imagebuilder-*.tar.xz --strip-components=1 && \
    rm openwrt-imagebuilder-*.tar.xz

RUN ccache -M 1G

COPY build-bpi-r4.sh /builder/
RUN chmod +x /builder/build-bpi-r4.sh

CMD ["./build-bpi-r4.sh"]