# D4Mac

A free, open-source launcher that runs the Windows (Battle.net) version of **Diablo IV** on
Apple Silicon Macs. It puts together public parts: Wine, Apple's D3DMetal, and DXMT.

You still need your own Diablo IV license and Battle.net account. D4Mac does not include
any game files, Blizzard software or Apple software.

## What it does

The app shows a setup checklist. Each step runs and turns green:

1. **Check this Mac**: Apple Silicon, macOS 14+, Rosetta 2, 20 GB free
2. **Download Wine**: open-source Wine 10 engine with MSync and D3DMetal support
3. **Import D3DMetal**: Apple's DirectX 12 → Metal layer (see below)
4. **Download DXMT**: open-source DirectX 11 → Metal, for the Battle.net window
5. **Create Windows environment**
6. **Import Diablo IV**: clones an existing install (no extra disk space), or skips
7. **Install Battle.net**: Blizzard's official installer

Then press **Play**.

## Getting D3DMetal

D3DMetal is Apple's code and cannot be shipped with D4Mac. D4Mac finds it in one of these places:

* **Apple's Game Porting Toolkit.** Sign in at
  <https://developer.apple.com/download/all/?q=game%20porting%20toolkit> with a free Apple ID,
  download *Game Porting Toolkit 3* (.dmg) to `~/Downloads`. D4Mac finds it.
* **A D3DMetal folder already on your Mac** (same layout as the toolkit's `redist/lib`:
  `external/libd3dshared.dylib` + `wine/`). Choose it with "Choose .dmg or folder…".

## Build

Needs Apple's Command Line Tools (`xcode-select --install`). Xcode is not required.

```sh
scripts/build-app.sh      # → dist/D4Mac.app
scripts/test.sh           # unit tests
```

There is also a command-line tool with the same features:

```sh
swift run d4mac status
swift run d4mac setup                     # all steps that are not done
swift run d4mac setup --d3dmetal ~/Downloads/Game_Porting_Toolkit_3.0.dmg d3dmetal
swift run d4mac play --hud                # Battle.net + Diablo IV, with the Metal FPS HUD
swift run d4mac stop
eval "$(swift run d4mac env)"; wine winecfg   # manual Wine commands
```

Data lives in `~/Library/Application Support/D4Mac/` (runtime, prefix, logs).
To remove everything, delete that folder.

## How it works

See [docs/SPEC.md](docs/SPEC.md) for the parts, the folder layout, and every environment
setting.

## Licenses

D4Mac is MIT licensed. Downloaded parts keep their own licenses. See [THIRD_PARTY.md](THIRD_PARTY.md).
