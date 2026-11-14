# Pinned dated tag (>= 3 days old at time of writing). Bump deliberately.
FROM debian:trixie-20261104-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cups cups-client cups-filters cups-ipp-utils ghostscript poppler-utils ca-certificates \
      avahi-daemon avahi-utils dbus \
 && rm -rf /var/lib/apt/lists/*

# Our config lives outside /etc/cups (which is a volume, see compose) and is installed on every start.
COPY cupsd.conf cups-files.conf.append /usr/local/share/cups-bridge/
RUN cp /etc/cups/cups-files.conf /usr/local/share/cups-bridge/cups-files.conf.stock
COPY avahi-daemon.conf /etc/avahi/avahi-daemon.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 631
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
