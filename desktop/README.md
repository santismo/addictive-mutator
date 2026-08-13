# AD2 Kit Architect for macOS

This is a local SwiftUI Logic preset studio for Addictive Drums 2. It scans only the standard Logic Audio Unit preset folder and provides:

- multi-preset mix blending: a base preset plus any number of influence presets; and
- a random mix-hybrid generator that chooses a fresh base, one to three influence presets, and a new blend strength on every run.

Every output is named after its source recipe, such as `modern bap + heavy united — hybrid.aupreset`. If the exact same source combination is generated again, the app adds a numerical suffix rather than overwriting a prior file.

It does not open, read, alter, or generate `.AD2Preset` contents. XLN does not document a preset file format or export API; creating valid files independently would require reverse engineering, which this project deliberately avoids. Use the generated build sheet in AD2 and save the finished result through AD2’s normal User Preset workflow.

For Logic presets, the app hosts the installed AD2 Audio Unit, loads the selected base and influence `.aupreset` files through the Audio Unit’s standard state API, blends only AD2 parameters made available to hosts, then asks AD2 for its own serialized state before writing a new Logic `.aupreset`. The base preset retains the entire kit selection—including all kit-piece choices—and other non-automatable internal AD2 state. The app never parses or edits the AD2-owned state block. Generated files are written only to `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/generated presets/`; an existing file is never overwritten.

## Run locally

```bash
cd desktop
swift run
```

To make a double-clickable local app bundle, run `./scripts/package-macos-app.sh`. It creates `build/AD2 Kit Architect.app` and deliberately refuses to replace an existing bundle.

The app looks only in these standard Logic locations:

- sources: `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/`
- output: `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/generated presets/`
