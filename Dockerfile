FROM resin/rpi-raspbian:latest

MAINTAINER Salvo Musumeci <info@salvomusumeci.com>

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -q -y update \
 && apt-get install -y apt-utils \
 && apt-get install -y isc-dhcp-server python3\
 
# && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" install apt-utils \
# && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" dist-upgrade \
# && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" install isc-dhcp-server man python3 \
 && apt-get -q -y autoremove \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/*

COPY util/my_init.py /sbin/my_init
COPY util/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
