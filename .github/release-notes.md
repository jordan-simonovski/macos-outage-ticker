**ONN — Outage News Network.** A macOS menu bar app that breaks into your screen
with a scrolling news ticker when the services you depend on go down.

## Install

```
brew install --cask jordan-simonovski/tap/onn
```

Or download **`ONN.dmg`**, open it, and drag **ONN** to Applications.
(`ONN.zip` is the same app if you prefer not to mount a disk image.)

ONN is ad-hoc signed but **not notarized**, so a manual install gets blocked on
first launch with "Apple could not verify ONN is free of malware". Clear it with:

```
xattr -dr com.apple.quarantine /Applications/ONN.app
```

The cask does this for you.

Universal binary (Apple silicon + Intel). Requires macOS 13 or later.
