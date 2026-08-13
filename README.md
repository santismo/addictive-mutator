# AD2 Kit Architect

An open-source, procedural companion for Addictive Drums 2.

The project has two parts:

- `desktop/` — the macOS SwiftUI preset studio. It combines existing Logic AD2 presets and includes a calibrated UI-automation workflow that makes new kit-piece combinations and saves them through AD2 itself.
- `app/` — an earlier browser-based interaction prototype. It demonstrates the generator controls but cannot read or write local AD2 files.

## Native app

The Logic preset workflow works only with `.aupreset` files. It does not scan the AD2 sample library or parse `.AD2Preset` files. Its Logic blends retain a base kit with blended Logic-exposed mix parameters. A separate opt-in Kit Mutator tab performs local, calibrated visible-UI automation in standalone AD2 to create individual kit-piece combinations, then relies on AD2’s own Save Preset operation to make the actual `.AD2Preset` file.

```bash
cd desktop
swift run
```

To create a local double-clickable application bundle:

```bash
cd desktop
./scripts/package-macos-app.sh
```

It produces `desktop/build/AD2 Kit Architect.app`.

## Important compatibility boundary

XLN does not provide a documented API or public file format for directly creating `.AD2Preset` files. Writing one independently would require reverse engineering its proprietary format, which this project deliberately does not do. The app therefore gives you a build sheet to apply in AD2 and save through AD2’s normal User Preset workflow.

If XLN publishes or approves a supported preset import/export API, that is the point to add one-click User Preset creation.

## License

The Kit Architect source code is available under the MIT License. Addictive Drums, AD2, ADpaks, Kitpiece Paks, presets, samples, and associated trademarks are property of XLN Audio; this project includes none of them.
