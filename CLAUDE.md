# selphy-cups-bridge

CUPS bridge for the Canon SELPHY CP1500: driverless printing from Windows via IPP Everywhere, discovered over DNS-SD

> **Visibility:** Public

## Directives

- All configuration (URLs, API keys, DB credentials, hostnames) **must** come from configuration files, never hardcoded. Prefer stable file-based formats (yaml, toml) for config; use environment variables **only** when there is genuinely no other way (e.g. a secret that must not touch disk, or a platform that injects config solely via env). Use generic placeholders in examples.
- **Read `docs/` before planning** — always consult existing research, findings, and design docs before proposing changes or starting new work. Start from the docs index (`docs/index.md`) to find the relevant document. The docs contain hard-won knowledge about API quirks, country-specific parsing rules, and known limitations.
- **Update `docs/` before committing** — when implementation reveals new findings, edge cases, or changes to architecture/decisions, update the relevant docs first, and keep the docs index (`docs/index.md`) in sync. Docs must stay in sync with the code. If a doc doesn't exist for a new area, create one and add it to the index.
- **Language** — all committed artifacts (code, comments, identifiers, commit messages, docs, `CLAUDE.md`) are written in **English**. The agent's conversation with the user may be in **any language** — match the user; only the artifacts are English-only.

## Sibling-project initialization

- If you create a **sibling project** (anything at `../<name>` outside this repo), don't leave it as a bare folder. Give it the same baseline setup this project has, before writing substantial code into it:
  - its own `CLAUDE.md` stating the project's purpose, directives, and intended visibility;
  - a `docs/` folder with an index (`docs/index.md`) for design notes and findings;
  - its own initialized git repository with a sensible `.gitignore`.
- First decide and record the new project's visibility (private vs. public) and apply matching precautions — e.g. keep personal data and internal hostnames/IPs out of anything that may become public.

## Public-project rules

- This is a **public** project (mirrored to GitHub with public visibility).
- **Never expose personal data** in code, comments, examples, commit messages, docs, or any committed file: IP addresses, hostnames, domain names of personal infra, API keys/tokens/passwords, asset/user IDs, GPS coordinates of real photos, or paths/filenames that reveal personal info. Store deployment-specific details in Claude memory (outside repo scope), not in project files. Use generic placeholders in examples.
- A `LICENSE` file is present; keep it accurate. Treat everything committed as world-readable.

## Project notes

- The design, the knobs and every gotcha found so far live in `README.md` (user-facing) and
  `docs/` (deeper notes). Read both before changing the PPD trim, the avahi config or the
  entrypoint.
- Configuration is via environment variables in `.env` next to `docker-compose.yml`: that is the
  platform convention for a published container, so it is the deliberate exception to the
  config-from-files directive. `.env` is gitignored; `.env.example` holds placeholders only.
- Changes are verified on real hardware (a SELPHY CP1500 + Windows 11). A change to anything a
  Windows client sees (media, defaults, DNS-SD record, queue identity) is not done until a print
  from Windows has been checked.
- Base image is pinned to a dated Debian tag; bump deliberately and keep it >= 3 days old.
