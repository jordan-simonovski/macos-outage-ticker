# NewsTicker

A macOS menu bar app that watches status pages and fires a scrolling
breaking-news ticker across your screen when something is down. Snark level
configurable. Hugops always.

## Run

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

## Test

    swift run TickerCoreTests

`TickerCore` is covered by a dependency-free assert harness rather than XCTest,
because Command Line Tools ships no XCTest module. On a machine with Xcode
installed, swap the `TickerCoreTests` executable target in `Package.swift` back
to a `.testTarget` and run `swift test`.

The AppKit layer has no unit tests. Its equivalent is:

    NEWSTICKER_SELFTEST=1 swift run

which prints menu state, config paths and ticker window geometry, then exits.
