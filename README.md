<div align="center">

<img src="docs/images/icon.png" width="128" alt="ONN">

# ONN — Outage News Network

**Breaking news, for when your dependencies break.**

A macOS menu bar app that watches status pages and cuts into your screen with a
scrolling news ticker the moment something goes down. Snark level configurable.
Hugops always.

[![CI](https://github.com/jordan-simonovski/macos-outage-ticker/actions/workflows/ci.yml/badge.svg)](https://github.com/jordan-simonovski/macos-outage-ticker/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/jordan-simonovski/macos-outage-ticker?label=release)](https://github.com/jordan-simonovski/macos-outage-ticker/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://github.com/jordan-simonovski/macos-outage-ticker/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<img src="docs/images/ticker.png" width="100%" alt="The ONN ticker reporting a GitHub outage">

</div>

## Install

Download **`ONN.dmg`** from [the latest release](https://github.com/jordan-simonovski/macos-outage-ticker/releases/latest),
open it, and drag **ONN** to Applications.

ONN is ad-hoc signed but **not notarized**, so macOS blocks it on first launch.
Either right-click the app → Open → Open, or run:

    xattr -dr com.apple.quarantine /Applications/ONN.app

Universal binary (Apple silicon + Intel), macOS 13+.

## What it does

ONN polls any [Atlassian Statuspage](https://www.atlassian.com/software/statuspage)-powered
status page. When one reports an incident, the ticker appears at the top or bottom of your
screen and scrolls the headline. When the incident resolves, it says so once and disappears.

Messages escalate with how often a service has broken lately — the fourth GitHub outage
this month does not get the same respect as the first:

| Outages in window | Tier | Sample (snarky) |
|---|---|---|
| 1 | fresh | "BREAKING: GitHub is down. Somewhere, an on-call phone is ruining a perfectly good lunch." |
| 2–4 | repeat offender | "BREAKING: GitHub is down AGAIN. At this point we should just leave this banner up." |
| 5+ | not even news | "GitHub is down. This isn't even news anymore." |

## Run from source

    swift run                    # menu bar only; ticker appears when something breaks
    NEWSTICKER_DEMO=1 swift run  # fire a sample ticker immediately

## Configure

Config lives at `~/Library/Application Support/ONN/config.json` (created on first run).
Edit it from the menu → Open Config, then → Reload Config.

| Key | Default | Meaning |
|---|---|---|
| `sites` | GitHub, ClickHouse, Atlassian, Claude | Statuspage-based pages to poll (`<url>/api/v2/status.json` must exist) |
| `pollIntervalSeconds` | 60 | How often to poll |
| `tone` | `balanced` | `hugops`, `balanced`, or `snarky` |
| `edge` | `bottom` | `top` or `bottom` of the screen |
| `historyWindowDays` | 30 | Window for counting repeat outages |
| `repeatOffenderThreshold` | 2 | Outages in window before "again?" messages |
| `notNewsThreshold` | 5 | Outages in window before "this isn't even news" |
| `scrollPointsPerSecond` | 120 | Ticker scroll speed |

Any Statuspage-powered page works — add `{"name": "Foo", "url": "https://status.foo.com"}`
to `sites`. A full scroll pass takes `(screenWidth + textWidth) / scrollPointsPerSecond`
seconds, so raise the speed if headlines feel slow.

## Build a release locally

    scripts/make-app.sh          # dist/ONN.app + dist/ONN.dmg, version from the git tag
    scripts/make-app.sh v1.2.3   # or pin the version explicitly
    swift scripts/make-icon.swift dist/ONN.icns   # regenerate the icon alone

CI builds and tests every push and PR. Pushing a `v*` tag also builds the universal
bundle and publishes the DMG and zip to a GitHub Release:

    git tag v1.0.0 && git push origin v1.0.0

## Test

    swift test

28 XCTest cases covering `TickerCore` — config, Statuspage parsing, the outage state
machine, history windows, message selection and the poll engine. Requires Xcode.

There is also a local fake Statuspage that flips services up and down on a timer, so you
can watch the ticker escalate without waiting for the real internet to break:

    python3 scripts/mock-status-server.py --up 30 --down 30
    NEWSTICKER_CONFIG=scripts/mock-config.json swift run

The AppKit layer has no unit tests. Its equivalent is:

    NEWSTICKER_SELFTEST=1 swift run

which prints menu state, config paths and ticker window geometry, then exits.

## License

MIT — see [LICENSE](LICENSE).
