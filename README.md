# DriveClub Recomp Club Badge fix

Saving an edited Club Badge exercises both the local client runtime and the EGS
server. This source-only contribution separates their changes.

- [01: PNG encoder HLE](patches/01-client-png-hle.patch) registers the four
  libScePngEnc functions and uses libpng to encode the guest image.
- [02: Vulkan readback](patches/02-client-vulkan-readback.patch) synchronizes the
  rendered tiled surface before the game's CPU converter reads it. The original
  converter still handles the tiled layout. The hook applies only when the game
  1.28 call-site signature matches.
- [03: Validation tools](patches/03-validation-tools.patch) checks the advertised
  Protobuf descriptor, uploads and both preview sizes across a server restart.
  It also checks real game PNGs against the upload trace and stored bytes.
- [04: Server schema](patches/04-club-badge-object-type.patch) advertises
  `BobObjectType = 5`. The game looks this value up before it sends the upload,
  and the old descriptor caused a null enum descriptor in `SetEnum`.
- [05: Server persistence](patches/05-club-badge-previews.patch) saves both BOB
  IDs in the existing club JSON and returns their URLs when requested. This
  requires no database migration.

## Verified versions

The real Windows game session used PS4 DriveClub 1.28, an isolated installation
whose directory was originally labeled 0.2.4, and a patched runtime built
from DriveClub Recomp commit `ca23464e2d9d2cc8bd887a243d5805d5d492baa3`.
Both previews had nontransparent pixels (36,770 at 256×256 and 2,384 at 64×64).
Encoder, SQLite and download SHA-256 hashes matched and the upload request
checksums matched the stored files. The user confirmed the badge remained
visible after restarting the client and server.

The upstream [v0.4.2 hotfix](https://github.com/OverkillLabs3/driveclub-recomp/releases/tag/v0.4.2)
is commit `e9d32b868c436de77dd0a21cc145e03e199db531`. Its tracked code matches
the verified client base. The upstream tag contains the encoder NID names
but lacks the HLE implementation and badge-specific readback. The patches
applied cleanly to this tag and a fresh Windows build linked and started
far enough to print usage. The prepared 1.28 image passed the signature check.
The fresh tag build has yet to complete an in-game badge save. Other releases
and Linux have not been tested for this fix.

The tested server base is
[Judaswick/driveclub-server coop](https://github.com/Judaswick/driveclub-server/tree/2233b4cbc168d086c186fac830e415a0d66bcbe1)
at `2233b4cbc168d086c186fac830e415a0d66bcbe1`, with patches 04 and 05 applied.
The synthetic upload and restart regression passed against that build.

## Updating and building

Use a new checkout and isolated game installation for each release. The
commands below start from the contribution bundle in PowerShell 7. Choose
a release tag and point the signature check at the prepared image from your
own game 1.28 installation.

```powershell
$bundle = (Get-Location).Path
$tag = 'v0.4.2'
$gameImage = Read-Host 'Path to your prepared boot-linked.bin'
git clone --no-checkout https://github.com/OverkillLabs3/driveclub-recomp.git client-review
git -C client-review fetch origin tag $tag
git -C client-review switch -c "fix/club-badge-$tag" $tag
& "$bundle/check-update.ps1" -Checkout ./client-review -GameImage $gameImage
# Apply after reviewing the compatibility result.
& "$bundle/check-update.ps1" -Checkout ./client-review -GameImage $gameImage -Apply

git clone https://github.com/Judaswick/driveclub-server.git server-review
git -C server-review switch -c fix/club-badge-server 2233b4cbc168d086c186fac830e415a0d66bcbe1
& "$bundle/check-update.ps1" -Checkout ./server-review -Component Server
& "$bundle/check-update.ps1" -Checkout ./server-review -Component Server -Apply
```

Stop if Git reports a conflict or the game signature changes. The script skips
patches that reverse-apply verbatim and stops on ambiguous changes. For an
independently implemented upstream fix, inspect the functional encoder
registrations, the CPU/GPU synchronization boundary, the actual EGS descriptor
and both persisted IDs and URLs. Omit a local patch only once the corresponding
regression passes against the upstream implementation. A future incompatible
image needs a new source address trace and a reviewed signature, with the
runtime guard left in place.

Build from the two checkouts using the release's build instructions and a
consistent MSYS2 CLANG64 environment. Tested versions were Clang 23.1.5,
libpng 1.6.59, OpenSSL 3.6.5, Protobuf 36.2.0 and Qt 6.12.0. Use the
new build's matching DLLs, including the server's Qt SQLite plugin.

```bash
cd client-review
bash build.sh
clang++ -std=c++17 tools/club_badge_schema_test.cpp \
  $(pkg-config --cflags --libs protobuf) -o out/club_badge_schema_test.exe
cd ../server-review
cmake -S . -B out -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_CXX_COMPILER=clang++ -DDRIVECLUB_SYSTEM_PROTOBUF=ON \
  -DGAME_SERVER_DEPLOY_QT=OFF -DDRIVECLUB_BUILD_ADMIN=OFF
cmake --build out --target driveclubsrv
```

Use the new release's packaging procedure for the client. Pair it with the
patched server in a separate test installation and use separate saves and a
separate database. A relative database path with a directory component, such
as `./driveclub.db`, keeps the tested server from falling back to its shared
database location. Set the client to the test server address.

Run the following from the client checkout with Python 3 available. The first
command starts an independent loopback server and verifies upload, metadata,
download and restart persistence. For the second command, save a visibly
nonempty badge in the real isolated game on port 18080. Enable
`BB_BADGE_PIXELS=1` and server request tracing for that run. The variable is
optional for ordinary play.

```powershell
python tools/test_club_badge_server.py --server ../server-review/out/driveclubsrv.exe --schema-check out/club_badge_schema_test.exe
python tools/check_club_badge_pixels.py --test-root ./out/club-badge-game-test --club 1 --client-log ./out/club-badge-game-test/logs/SAVE-RUN.stderr.log
```

Use your actual club ID and stderr log. Check the editor, a car livery and
the menu. Restart both processes and check the menu again. Save again to
replace any earlier blank uploads. Keep the previous working installation
available until the new client and server pass the entire test.

## Credits and license

The PNG encoder is adapted from [shadPS4's libScePngEnc implementation](https://github.com/shadps4-emu/shadPS4/blob/main/src/core/libraries/libpng/pngenc.cpp).
The imported source retains the shadPS4 Emulator Project copyright and
`GPL-2.0-or-later` SPDX notices. The exact donor revision was not recorded
in the original import. The DriveClub Recomp source is distributed with its
repository GPL license. Server patches are intended for the server repository
under its existing licensing terms. The contribution contains source patches
and test code. The game and runtime data are supplied separately by testers.

The investigation and implementation were completed with assistance from
OpenAI Codex. Final functionality was validated in a real isolated game session.
