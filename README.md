# AD2 Kit Architect

An open-source, procedural companion for Addictive Drums 2.

The project has two parts:

- `desktop/` — the macOS SwiftUI companion app. This is the real product direction: it discovers the AD2 library installed on the Mac, lists available ADpaks/Kitpiece Paks and user presets, and makes deterministic build sheets.
- `app/` — an earlier browser-based interaction prototype. It demonstrates the generator controls but cannot read or write local AD2 files.

## Native app

The macOS app reads only safe filesystem metadata: installed content-package names and the names of user presets. It never opens AD2 content packages or parses `.AD2Preset` files.

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
