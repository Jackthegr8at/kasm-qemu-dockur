FROM kasmweb/core-ubuntu-noble:1.17.0

ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

ARG VERSION_ARG="0.00"
ARG VERSION_VNC="1.6.0"

ENV HOME /home/kasm-default-profile
ENV STARTUPDIR /dockerstartup
ENV INST_SCRIPTS $STARTUPDIR/install
WORKDIR $HOME

USER root

RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        bc \
        jq \
        tini \
        wget \
        7zip \
        curl \
        fdisk \
        nginx \
        swtpm \
        procps \
        iptables \
        iproute2 \
        apt-utils \
        dnsmasq \
        xz-utils \
        net-tools \
        e2fsprogs \
        qemu-utils \
        iputils-ping \
        genisoimage \
        ca-certificates \
        qemu-system-x86 \
        qemu-system-gui && \
    apt-get clean && \
    mkdir -p /etc/qemu && \
    echo "allow br0" > /etc/qemu/bridge.conf && \
    wget "https://snapshot.debian.org/archive/debian/20250128T092032Z/pool/main/e/edk2/ovmf_2024.11-5_all.deb" -O /tmp/ovmf.deb -q --timeout=10 && \
    dpkg -i /tmp/ovmf.deb && \
    mkdir -p /usr/share/novnc && \
    wget "https://github.com/novnc/noVNC/archive/refs/tags/v${VERSION_VNC}.tar.gz" -O /tmp/novnc.tar.gz -q --timeout=10 && \
    tar -xf /tmp/novnc.tar.gz -C /tmp/ && \
    cd "/tmp/noVNC-${VERSION_VNC}" && \
    mv app core vendor package.json *.html /usr/share/novnc && \
    unlink /etc/nginx/sites-enabled/default && \
    sed -i 's/^worker_processes.*/worker_processes 1;/' /etc/nginx/nginx.conf && \
    echo "$VERSION_ARG" > /run/version && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-add-repository ppa:remmina-ppa-team/remmina-next

RUN apt-get update \
    && apt-get -y install \
        nano \
        filezilla \
        xrdp \
        rdesktop \
        remmina \
        remmina-plugin-rdp

RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        wsdd \
        samba \
        wimtools \
        dos2unix \
        cabextract \
        libxml2-utils \
        libarchive-tools \
        netcat-openbsd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Google Chrome
COPY ./src/ubuntu/install/chrome $INST_SCRIPTS/chrome/
RUN bash $INST_SCRIPTS/chrome/install_chrome.sh  && rm -rf $INST_SCRIPTS/chrome/

# Install Firefox
COPY ./src/ubuntu/install/firefox/ $INST_SCRIPTS/firefox/
#COPY ./src/ubuntu/install/firefox/firefox.desktop $HOME/Desktop/
#RUN bash $INST_SCRIPTS/firefox/install_firefox.sh && rm -rf $INST_SCRIPTS/firefox/

# Install Microsoft Edge
COPY ./src/ubuntu/install/edge $INST_SCRIPTS/edge/
#RUN apt-get update \
#&& bash $INST_SCRIPTS/edge/install_edge2.sh  && rm -rf $INST_SCRIPTS/edge/

COPY custom_startup.sh $STARTUPDIR/custom_startup.sh
RUN chmod +x $STARTUPDIR/custom_startup.sh
RUN chmod 755 $STARTUPDIR/custom_startup.sh

#RUN apt-get update \
#    && apt-get install -y sudo \
#    && echo 'kasm-user ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
#    && rm -rf /var/lib/apt/list/*


RUN mkdir /storage
#VOLUME /storage
RUN chown -R 1000:1000 /storage

COPY --chmod=755 ./web /var/www/
COPY --chmod=755 ./src /run/
COPY --chmod=664 ./web/conf/defaults.json /usr/share/novnc
COPY --chmod=664 ./web/conf/mandatory.json /usr/share/novnc

ADD --chmod=664 https://github.com/qemus/virtiso-whql/releases/download/v1.9.45-0/virtio-win-1.9.45.tar.xz /var/drivers.txz

COPY --chmod=755 ./assets /run/assets

COPY --chmod=744 ./web/conf/nginx.conf /etc/nginx/sites-enabled/web.conf

RUN chmod +x /run/*.sh

RUN mv /run/w10slim.remmina $HOME/Desktop/w10.remmina

COPY run.sh $HOME/Desktop/run.sh

# Update the desktop environment to be optimized for a single application
#RUN cp $HOME/.config/xfce4/xfconf/single-application-xfce-perchannel-xml/* $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/
#RUN cp /usr/share/backgrounds/bg_kasm.png /usr/share/backgrounds/bg_default.png
#RUN apt-get remove -y xfce4-panel

ENV VERSION="2022"
ENV QEMUDISPLAY "gtk,full-screen=on"
ENV CPU_CORES="2"
ENV RAM_SIZE="6G"
ENV DISK_SIZE="45G"
ENV BOOT_MODE: "windows"
ENV BOOT="boot.img"

RUN chown 1000:0 $HOME
RUN $STARTUPDIR/set_user_permission.sh $HOME

ENV HOME /home/kasm-user
WORKDIR $HOME
RUN mkdir -p $HOME && chown -R 1000:0 $HOME

USER 1000
