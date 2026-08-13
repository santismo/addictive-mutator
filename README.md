# AD2 Kit Architect

An open-source, procedural companion for Addictive Drums 2.

The project has two parts:

- `desktop/` — the macOS SwiftUI Logic-preset studio. This is the real product direction: it combines existing Logic AD2 presets and creates fresh, loadable `.aupreset` hybrids.
- `app/` — an earlier browser-based interaction prototype. It demonstrates the generator controls but cannot read or write local AD2 files.

## Native app

The macOS app works only with Logic `.aupreset` files. It does not scan the AD2 sample library or parse `.AD2Preset` files. It creates a base-kit preset with blended Logic-exposed mix parameters; it does not mix individual AD2 kit pieces between presets.

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
