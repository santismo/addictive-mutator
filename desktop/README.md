# AD2 Kit Architect for macOS

This is a local SwiftUI Logic preset studio for Addictive Drums 2. It scans only the standard Logic Audio Unit preset folder and provides:

- multi-preset mix blending: a base preset plus any number of influence presets; and
- a random mix-hybrid generator that chooses a fresh base, one to three influence presets, and a new blend strength on every run.
- an **AD2 Kit Mutator** tab that mutates individually captured Kit-page slots, then optionally saves the result through AD2’s own Save Preset dialog.

Every output is named after its source recipe, such as `modern bap + heavy united — hybrid.aupreset`. If the exact same source combination is generated again, the app adds a numerical suffix rather than overwriting a prior file.

It does not open, read, alter, or generate `.AD2Preset` contents. XLN does not document a preset file format or export API; creating valid files independently would require reverse engineering, which this project deliberately avoids. Use the generated build sheet in AD2 and save the finished result through AD2’s normal User Preset workflow.

For Logic presets, the app hosts the installed AD2 Audio Unit, loads the selected base and influence `.aupreset` files through the Audio Unit’s standard state API, blends only AD2 parameters made available to hosts, then asks AD2 for its own serialized state before writing a new Logic `.aupreset`. The base preset retains the entire kit selection—including all kit-piece choices—and other non-automatable internal AD2 state. The app never parses or edits the AD2-owned state block. Generated files are written only to `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/generated presets/`; an existing file is never overwritten.

## AD2 Kit Mutator (beta)

This opt-in workflow creates genuinely new kit-piece combinations in the standalone AD2 app without manipulating any preset file. After granting macOS Accessibility permission, calibrate the right-facing **next** arrow for each Kit-page slot you want included. The mutator will bring standalone AD2 forward and click a randomized subset of those locations. Since AD2 itself cycles the kit-piece browser, it stays within the content installed and licensed by the user.

You can optionally calibrate the three controls in AD2’s Save Preset dialog: the initial Save button, the preset-name field, and the final Save button. The app then types a unique name and lets AD2 write the normal `.AD2Preset` User Preset. Coordinates are local to your display and UI scale, stored only in this app’s local preferences, and never shared. Recalibrate after changing screen layout or AD2 UI scaling.

## Run locally

```bash
cd desktop
swift run
```

To make a double-clickable local app bundle, run `./scripts/package-macos-app.sh`. It creates `build/AD2 Kit Architect.app` and deliberately refuses to replace an existing bundle.

The app looks only in these standard Logic locations:

- sources: `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/`
- output: `~/Library/Audio/Presets/XLN Audio/Addictive Drums 2/generated presets/`
