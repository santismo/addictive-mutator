# AD2 Kit Architect for macOS

This is a local SwiftUI companion app for Addictive Drums 2. It scans standard AD2 install locations on macOS and shows:

- installed ADpaks and Kitpiece Paks, inferred from their installed content-package names;
- names of existing user presets; and
- deterministic, procedural build directions that only suggest installed ADpaks; and
- a Logic preset blender that creates a real `.aupreset` from a selected base and influence preset.

It does not open, read, alter, or generate `.AD2Preset` contents. XLN does not document a preset file format or export API; creating valid files independently would require reverse engineering, which this project deliberately avoids. Use the generated build sheet in AD2 and save the finished result through AD2’s normal User Preset workflow.

For Logic presets, the app hosts the installed AD2 Audio Unit, loads the selected base and influence `.aupreset` files through the Audio Unit’s standard state API, blends only AD2 parameters made available to hosts, then asks AD2 for its own serialized state before writing a new Logic `.aupreset`. The base preset retains the kit selection and other non-automatable internal AD2 state. The app never parses or edits the AD2-owned state block. Generated files are written only to `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/generated presets/`; an existing file is never overwritten.

## Run locally

```bash
cd desktop
swift run
```

To make a double-clickable local app bundle, run `./scripts/package-macos-app.sh`. It creates `build/AD2 Kit Architect.app` and deliberately refuses to replace an existing bundle.

The scanner looks in these standard locations:

- `~/Library/Application Support/Addictive Drums 2/`
- `/Library/Application Support/XLN Audio/Addictive Drums 2/Sound Data/`
