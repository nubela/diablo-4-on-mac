# D4Mac functional spec (clean-room)

This spec describes **what** a Diablo IV launcher for Apple Silicon must do. It was written
from public facts only: the public file layout, license files, and the shipped user docs of
an existing commercial launcher, plus upstream docs for Wine, CrossOver, Apple's Game
Porting Toolkit and DXMT. No source code, patched source or disassembly of that launcher
was read or used, and none of its files are in this repository.

## Parts

| Part | Role | Source | License |
|---|---|---|---|
| Wine engine | Runs Windows programs (x86_64, under Rosetta 2) | Sikarugir engine `WS12WineSikarugir10.0_8` (Wine 10 with CrossOver-style MSync + D3DMetal hooks) | LGPL |
| Runtime libraries | FreeType, GnuTLS, SDL2, GStreamer, … loaded by Wine | `Contents/Frameworks` of Sikarugir `Template-1.0.21`, **without** its `renderer/` folder | various open source |
| D3DMetal | Direct3D 11/12 → Metal for the 64-bit game | Apple Game Porting Toolkit, from the user's own copy | Apple license, never redistributed |
| DXMT | Direct3D 11 → Metal for **32-bit** programs (Battle.net launcher UI) | 3Shain/dxmt v0.72 | MIT |

## Runtime layout

```
runtime/wine/                 Wine engine (bin/, lib/wine/, share/)
runtime/wine/lib/external/    D3DMetal.framework + libd3dshared.dylib
runtime/wine/lib/wine/x86_64-windows/   D3DMetal d3d11/d3d12/dxgi/... PE DLLs
runtime/wine/lib/wine/x86_64-unix/      D3DMetal *.so (symlinks to ../../external/libd3dshared.dylib), DXMT winemetal.so
runtime/wine/lib/wine/i386-windows/     DXMT d3d11/dxgi/d3d10core/winemetal (32-bit)
runtime/Frameworks/           runtime libraries
prefix/                       Wine prefix (Windows 10)
```

`lib/external` must sit next to `lib/wine` because D3DMetal's Unix-side files are relative
symlinks to `../../external/libd3dshared.dylib`.

## Environment for every Wine process

| Variable | Value | Why |
|---|---|---|
| `WINEPREFIX` | `prefix/` | the Windows environment |
| `WINEMSYNC` | `1` | fast thread sync on macOS (Mach semaphores) |
| `ROSETTA_ADVERTISE_AVX` | `1` | Rosetta 2 reports AVX; Diablo IV needs it |
| `CX_APPLEGPTK_LIBD3DSHARED_PATH` | `runtime/wine/lib/external/libd3dshared.dylib` | where Wine finds D3DMetal's bridge |
| `DYLD_FALLBACK_LIBRARY_PATH` | `runtime/Frameworks`, GStreamer libs, `lib/external`, `/usr/lib` | libraries Wine loads |
| `WINEDLLOVERRIDES` | `winemenubuilder.exe=d` | no Windows shortcuts in macOS menus |
| `WINEDEBUG` | `-all` (or detailed when debugging) | speed |
| `MTL_HUD_ENABLED` | `1` only when the user asks | Metal FPS overlay |

## Setup steps

1. Check Mac: Apple Silicon, macOS 14+, Rosetta 2 (installs it if missing), 20 GB free.
2. Download Wine engine + libraries (SHA-256 pinned).
3. Import D3DMetal from the user's GPTK `.dmg` (handles a nested `.dmg`) or from an existing
   D3DMetal folder with the same layout. Not needed for steps 4–7.
4. Download DXMT; put the 32-bit DLLs and `winemetal.so` into the engine.
5. `wineboot --init`, `winecfg -v win10`.
6. If an existing Battle.net Diablo IV install is found, APFS-clone it (`cp -cR`) into the
   prefix. The original is not changed. Otherwise skip; the user installs from Battle.net.
7. Run Blizzard's official Battle.net installer; done when `Battle.net Launcher.exe` exists.

## Launch

* Open Battle.net: `wine "C:\Program Files (x86)\Battle.net\Battle.net Launcher.exe"`
* Play: same, plus `--exec="launch Fen"` (Fen = Diablo IV product code).
* Stop: `wineserver -k`.

## Known differences / open items

* The reference launcher uses Wine 11 (CrossOver 26.3). The public Sikarugir Wine 11 builds
  (`11.0`, `11.0_1`) fail to start any child process on macOS 26.5 (the process exits with
  code 1 right after loading `ntdll.dll`), so D4Mac pins Wine 10.
* The reference launcher carries a small `ntdll` change to `NtQueryDirectoryObject`
  (BOOLEAN return type). Not needed so far: with the stock Wine 10 engine, Battle.net
  installs, signs in, and starts Diablo IV 3.2.2 to the character select screen
  (M4 Pro, macOS 26.5.2).
