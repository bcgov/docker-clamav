FROM docker-remote.artifacts.developer.gov.bc.ca/debian:buster-20201209

# Debian Base to use
ENV DEBIAN_VERSION buster

# initial install of av daemon
RUN echo "deb http://http.debian.net/debian/ $DEBIAN_VERSION main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://http.debian.net/debian/ $DEBIAN_VERSION-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/ $DEBIAN_VERSION/updates main contrib non-free" >> /etc/apt/sources.list

RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -qq \
        clamav-daemon \
        clamav-freshclam \
        libclamunrar9 \
        wget \
        ca-certificates

RUN DEBIAN_FRONTEND=noninteractive apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# initial update of av databases
RUN wget -O /var/lib/clamav/main.cvd https://clamav-mirror.apps.silver.devops.gov.bc.ca/main.cvd && \
    wget -O /var/lib/clamav/daily.cvd https://clamav-mirror.apps.silver.devops.gov.bc.ca/daily.cvd && \
    wget -O /var/lib/clamav/bytecode.cvd https://clamav-mirror.apps.silver.devops.gov.bc.ca/bytecode.cvd && \
    chown clamav:clamav /var/lib/clamav/*.cvd

# permission juggling
RUN mkdir /var/run/clamav && \
    chown clamav:clamav /var/run/clamav && \
    chmod 750 /var/run/clamav
    
# Change the group ownerships for few folders in order to run Clamav in OpenShift.
# OpenShift runs the container as an user specified by OpenShift, it is neither root or Clamav user but the user belongs root group.
RUN chgrp -R root /var/log/clamav && \
    chmod -R g+w /var/log/clamav && \
    chgrp -R root /var/lib/clamav && \
    chmod -R g+w /var/lib/clamav && \
    chgrp -R root /run/clamav && \
    chmod -R g+w /run/clamav && \
    chgrp -R root /var/run/clamav && \
    chmod -R g+w /var/run/clamav

# av configuration update
RUN sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf && \
    sed -i '/LocalSocketGroup/d' /etc/clamav/clamd.conf && \
    sed -i 's/^SelfCheck 3600/SelfCheck 28800/g' /etc/clamav/clamd.conf && \
    echo "TCPSocket 3310" >> /etc/clamav/clamd.conf && \
    sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf && \
    sed -i 's/^ConnectTimeout 30/ConnectTimeout 90/g' /etc/clamav/freshclam.conf && \
    sed -i 's/^Checks 24/Checks 1/g' /etc/clamav/freshclam.conf && \
    sed -i 's/^# Check for new database 24 times a day/# Check for new database once a day/g' /etc/clamav/freshclam.conf && \
    sed -i '/DatabaseMirror/d' /etc/clamav/freshclam.conf && \
    echo "DatabaseMirror https://clamav-mirror.apps.silver.devops.gov.bc.ca" >> /etc/clamav/freshclam.conf

# volume provision
VOLUME ["/var/lib/clamav"]

# port provision
EXPOSE 3310

# av daemon bootstrapping
ADD bootstrap.sh /
CMD ["/bootstrap.sh"]
