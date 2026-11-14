# cups-bridge — Canon SELPHY CP1500 for Windows (and anything else) via CUPS

Status: **works.** Borderless prints from Windows (Lightroom Classic) since 2026-11-14; the queue
is discovered by Windows "Add device" over DNS-SD.

## Why

The SELPHY CP1500 is AirPrint- and Mopria-certified, but printing to it straight from Windows
(Microsoft IPP Class Driver) either hung, offered no colour choice, or both. AirPrint from Apple
devices works because macOS/iOS render the job themselves (CUPS) and send the printer a raster it
likes. This container does the same for everyone else: Windows prints PDF to a CUPS queue, CUPS
renders it and talks IPP Everywhere to the printer.

## What it does

- Builds the queue with `lpadmin -m everywhere` from the printer's own IPP attributes, then trims
  the generated PPD:
  - **one paper: 100x148 (`jpn_hagaki_100x148mm`), borderless only.** CUPS 2.4 publishes each
    `*.Borderless` PageSize as a separate media keyword (`om_postcard-borderless_100x148mm`), so
    Windows showed two 100x148 papers and flagged "100x148mm + Borderless" as a conflict. One
    full-page size avoids that. Borders, if wanted, come from the app (Lightroom margins, Photos
    "shrink to fit"). Windows labels this size **"Japanese Postcard"** — the standard name for
    100x148, i.e. the KP-36IP paper.
  - the real model name instead of `Printer`, suffixed `(CUPS bridge)` so it is not confused with
    the printer's own advertisement;
  - no `Draft` quality (300x150 dpi).
- Defaults are set at IPP level (`media`, `print-scaling-default=fill`): a PPD `PageSize` default
  set via `lpadmin -o PageSize=` did not reach `media-col-default`.
- Publishes the queue over DNS-SD (avahi inside the container, host networking), IPv4 only.

## Run

```sh
cp .env.example .env    # set PRINTER_URI
docker compose up -d --build
```

`docker-compose.yml` uses host networking (DNS-SD must reach the LAN; clients connect to `:631`)
and a volume for `/etc/cups`. Options, all via environment:

| Variable | Default | |
|---|---|---|
| `PRINTER_URI` | — (required) | e.g. `ipp://192.168.1.50:631/ipp/print` |
| `QUEUE_NAME` | `selphy` | queue URL is `http://<host>:631/printers/<name>` |
| `MODEL_NAME` | `Canon SELPHY CP1500 (CUPS bridge)` | shown in Windows and in DNS-SD |
| `PRINT_SCALING` | `fill` | `fill` / `fit` / `auto` / `none` |
| `DNSSD` | `1` | `0` skips avahi (e.g. behind Docker NAT, where multicast does not get out) |

The printer must be reachable at start: the queue is generated from its live IPP attributes.
Logs (CUPS error + access log) go to `docker logs`.

## Windows

Settings → Printers & scanners → **Add device**: pick **`Canon SELPHY CP1500 (CUPS bridge) @
<host>`**, not the plain `Canon SELPHY CP1500` (that is the printer itself, the path that hangs).
The driver is the built-in Microsoft IPP Class Driver.

Manual alternative: "Add manually" → "Add a printer using an IP address or hostname" → **IPP
Device** → `http://<host>:631/printers/selphy`. ("Select a shared printer by name" is the legacy
internet-printing client, which asks for a driver.)

Print photos from a photo app (Photos, Lightroom), not from a browser: Chrome lays a web page out
on paper and will split a large image across several sheets.

## Gotchas this design works around

- **Queue UUID must survive restarts.** Windows binds a discovered printer to the `printer-uuid`
  in the DNS-SD record; a re-created queue gets a new one and Windows' printer silently stops
  working ("error" on print, no request reaches CUPS). Hence the `/etc/cups` volume,
  `DirtyCleanInterval 0` (CUPS otherwise writes `printers.conf` ~30 s late) and SIGTERM
  forwarding in the entrypoint (PID 1 is a shell; without it cupsd is SIGKILLed unsaved).
- **No AAAA over mDNS** (`publish-aaaa-on-ipv4=no`). avahi publishes the link-local IPv6 address
  even with `use-ipv6=no`; CUPS listens on IPv4 only, and Windows tried IPv6 first — ~4 s per
  connection by name, which made "Add device" sit in "Connecting".
- **avahi only on the LAN interface** (`allow-interfaces=eth0`), or the service is published on
  `docker0` and every Docker bridge too. Change it if your interface is not `eth0`.
- In CUPS 2.x `ErrorLog`/`AccessLog`/`PageLog` belong in `cups-files.conf`; `MaxLogSize` and
  `DirtyCleanInterval` stay in `cupsd.conf` (cupsd refuses to start otherwise).

## Deferred

- **Other paper sizes** — L (89x119, `om_dsc-photo_89x119mm`) and card (54x86,
  `om_card_54x86mm`). The printer supports them; removed only because the author uses postcard
  paper. Would need a per-size switch (env) in the PPD trim.
- Publishing: image to a registry, generic printer support (the PPD trim is SELPHY-specific).
