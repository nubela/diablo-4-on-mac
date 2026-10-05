# Third-party software

D4Mac does not include any of these in its source or app bundle. It downloads or imports
them at setup time on the user's Mac.

| Software | Use | License | Where from |
|---|---|---|---|
| Wine (Sikarugir engine build) | Runs Windows programs | LGPL 2.1+ | https://github.com/Sikarugir-App/Engines (source: https://github.com/Sikarugir-App/wine) |
| Sikarugir template libraries (FreeType, GnuTLS, SDL2, GStreamer, …) | Libraries Wine loads | Each library's own open-source license | https://github.com/Sikarugir-App/Template |
| DXMT | Direct3D 11 → Metal for 32-bit programs | MIT | https://github.com/3Shain/dxmt |
| Apple D3DMetal (Game Porting Toolkit) | Direct3D 11/12 → Metal | Apple license (see `License.rtf` in the toolkit) | The user's own download from https://developer.apple.com/games/game-porting-toolkit/ |
| Battle.net | Blizzard launcher | Blizzard EULA | Official installer from battle.net |
