**ONN — Outage News Network.** A macOS menu bar app that breaks into your screen
with a scrolling news ticker when the services you depend on go down.

## Install

Download **`ONN.dmg`**, open it, and drag **ONN** to Applications.
(`ONN.zip` is the same app if you prefer not to mount a disk image.)

ONN is ad-hoc signed but **not notarized**, so macOS blocks it on first launch.
Either right-click the app → Open → Open, or run:

```
xattr -dr com.apple.quarantine /Applications/ONN.app
```

Universal binary (Apple silicon + Intel). Requires macOS 13 or later.
