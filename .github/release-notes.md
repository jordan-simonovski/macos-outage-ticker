Download `NewsTicker.zip` below, unzip, and drag **NewsTicker.app** to `/Applications`.

The app is ad-hoc signed but **not notarized**, so macOS will refuse to open it on first
launch. Either **right-click the app → Open → Open**, or run:

```
xattr -dr com.apple.quarantine /Applications/NewsTicker.app
```

It lives in the menu bar (📰) — no Dock icon, and no window until something breaks.
Universal binary, requires macOS 13 or later.
