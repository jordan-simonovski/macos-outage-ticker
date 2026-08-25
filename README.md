# NewsTicker

A macOS menu bar app that watches status pages and fires a scrolling
breaking-news ticker across your screen when something is down. Snark level
configurable. Hugops always.

## Install

Grab the latest `NewsTicker.zip` from [Releases](https://github.com/jordan-simonovski/macos-outage-ticker/releases),
unzip, and drag **NewsTicker.app** to `/Applications`.

The app is ad-hoc signed but **not notarized**, so macOS blocks it on first launch.
Either right-click the app → Open → Open, or:

    xattr -dr com.apple.quarantine /Applications/NewsTicker.app

Universal binary (Apple silicon + Intel), macOS 13+.

## Run from source

    swift run

Requires macOS 13+. No dependencies. The app lives in the menu bar (📰) —
no Dock icon, no window until something breaks.

Try it immediately:

    NEWSTICKER_DEMO=1 swift run

or use 📰 → Test Ticker.

## Configure

Config lives at `~/Library/Application Support/NewsTicker/config.json`
(created on first run). Edit it (📰 → Open Config), then 📰 → Reload Config.

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

Any Atlassian Statuspage-powered page works — add
`{"name": "Foo", "url": "https://status.foo.com"}` to `sites`.

## Build a release locally

    scripts/make-app.sh            # dist/NewsTicker.app, version from the current git tag
    scripts/make-app.sh v1.2.3     # or pin the version explicitly

CI builds and tests every push and PR. Pushing a `v*` tag additionally builds the
universal bundle and publishes it to a GitHub Release:

    git tag v1.0.0 && git push origin v1.0.0

## Test

    swift test

28 XCTest cases covering `TickerCore`. Requires Xcode — Command Line Tools alone
ships no XCTest module.

The AppKit layer has no unit tests. Its equivalent is:

    NEWSTICKER_SELFTEST=1 swift run

which prints menu state, config paths and ticker window geometry, then exits.
