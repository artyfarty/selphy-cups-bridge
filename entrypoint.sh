#!/bin/sh
set -eu
: "${PRINTER_URI:?set PRINTER_URI, e.g. ipp://192.168.1.50:631/ipp/print}"
QUEUE="${QUEUE_NAME:-selphy}"
MODEL="${MODEL_NAME:-Canon SELPHY CP1500 (CUPS bridge)}"
SCALING="${PRINT_SCALING:-fill}"

# /etc/cups is a volume so the queue (and its printer-uuid) survives restarts: Windows binds
# a discovered printer to that UUID, and a re-created queue gets a new one. Our config files
# are re-installed on every start so image updates still apply.
S=/usr/local/share/cups-bridge
cp "$S/cupsd.conf" /etc/cups/cupsd.conf
cat "$S/cups-files.conf.stock" "$S/cups-files.conf.append" > /etc/cups/cups-files.conf

# DNS-SD: CUPS publishes shared queues through avahi over D-Bus. Needs host networking.
# DNSSD=0 to skip (e.g. behind Docker NAT, where multicast does not get out anyway).
if [ "${DNSSD:-1}" = 1 ]; then
  mkdir -p /run/dbus && rm -f /run/dbus/pid /run/avahi-daemon/pid
  dbus-daemon --system --fork
  avahi-daemon --daemonize --no-chroot
fi

/usr/sbin/cupsd -f &
CUPSD=$!
# PID 1 is this shell: forward SIGTERM so cupsd exits cleanly instead of being SIGKILLed.
trap 'kill -TERM "$CUPSD" 2>/dev/null; wait "$CUPSD"; exit 0' TERM INT
until lpstat -r >/dev/null 2>&1; do sleep 0.5; done

# `everywhere` builds the PPD from the printer's own IPP attributes, so the printer must be up.
until ipptool -q "$PRINTER_URI" get-printer-attributes.test; do
  echo "waiting for printer at $PRINTER_URI ..."; sleep 10
done
lpadmin -p "$QUEUE" -E -v "$PRINTER_URI" -m everywhere -D "$MODEL"  # -D here: the DNS-SD name is taken at registration

# Trim the generated PPD to one paper: 100x148 (IPP jpn_hagaki_100x148mm), borderless.
# Why: CUPS 2.4 exposes each ".Borderless" PageSize as a separate media keyword
# (om_postcard-borderless_100x148mm), so Windows shows two 100x148 papers and flags
# "100x148mm + Borderless" as a conflict. With a single full-page "Postcard" the queue
# advertises one media with 0 margins; borders, if wanted, come from the app (LR margins,
# Photos "shrink to fit").
# Also: real model name instead of "Printer", and no "Draft" quality (300x150 dpi).
PPD=/etc/cups/ppd/$QUEUE.ppd
sed -E \
  -e '/^\*(PageSize|PageRegion|ImageableArea|PaperDimension) (54x86mm|89x119mm)(\.Borderless)?:/d' \
  -e '/^\*(PageSize|PageRegion|ImageableArea|PaperDimension) Postcard:/d' \
  -e 's/Postcard\.Borderless/Postcard/g' \
  -e 's/^\*Default(PageSize|PageRegion|ImageableArea|PaperDimension): .*/*Default\1: Postcard/' \
  -e '/^\*cupsPrintQuality Draft/d' \
  -e 's/^\*DefaultcupsPrintQuality: .*/*DefaultcupsPrintQuality: Normal/' \
  -e "s/^\*(ModelName|NickName|ShortNickName): .*/*\1: \"$MODEL\"/" \
  -e "s/^\*Product: .*/*Product: \"($MODEL)\"/" \
  "$PPD" > /tmp/trimmed.ppd

lpadmin -p "$QUEUE" -E -v "$PRINTER_URI" -P /tmp/trimmed.ppd -D "$MODEL" \
  -o printer-is-shared=true -o print-scaling-default="$SCALING" 2>/dev/null
lpadmin -d "$QUEUE"
echo "queue $QUEUE ready: $MODEL, 100x148 borderless, print-scaling=$SCALING"

wait $CUPSD
