# Addictive Mutator for macOS

Addictive Mutator is a local companion app for procedurally randomizing the visible Addictive Drums 2 Kit page. It never reads, changes, or generates AD2 preset files.

## What it does

- Calibrates the Kit page through click-to-capture controls.
- Matches AD2’s 18-slot layout: Cym 1–6, Tom 1–4, Ride 1–2, Kick, Snare, Hi-hat, and Flexi 1–3.
- Lets you include or skip every Kit piece independently, then randomizes only the included, prepared pieces in physical Kit-page order to reduce pointer travel.
- Stores calibrations, inclusion switches, and the chosen click interval locally, so they survive restarts and follow the calibrated window when it moves or resizes. Existing captures from the earlier AD2 Kit Architect name are migrated automatically.
- Starts in Quiet pointer mode at a 30 ms click interval; both remain adjustable if a particular AD2 setup needs more time.
- Targets either standalone AD2 or an open, focused AD2 editor inside Logic Pro; their calibrations are kept separate.
- Can use a mapped Logic Pro Kit page as the non-destructive fallback for unmapped standalone controls. Test one arrow first: the AD2 content is shared, but a host window's outer chrome can vary.
- Provides an `AdMu` macOS menu-bar action for an already-calibrated Logic AD2 editor.

The app uses macOS Accessibility permission to drive AD2’s visible interface. AD2 itself selects from the content you already have installed.

## Run locally

```bash
cd desktop
swift run
```

To create a double-clickable app bundle with the custom drum icon:

```bash
./scripts/package-macos-app.sh
```

This creates `build/Addictive Mutator.app` without overwriting an existing bundle.

To make a simple drag-to-install macOS disk image (open it and drag the app to Applications):

```bash
./scripts/create-dmg.sh 'Addictive Mutator.app' 'Addictive Mutator.dmg'
```

The project is unsigned for now, so macOS may ask you to approve the first launch in Privacy & Security. A Developer ID certificate and Apple notarization are required to remove that warning for public releases.

For the standard macOS Installer wizard, which installs the app into Applications:

```bash
./scripts/create-installer-pkg.sh 'Addictive Mutator.app' 'Addictive Mutator.pkg'
```

The source is licensed under the [MIT License](../LICENSE), Copyright © 2026 Santismo.
