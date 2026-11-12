Fix Club Badge PNG export on DriveClub 1.28

Related to #288.

In an online club, edit a badge, save it, then view the club menu. On the
investigated setup the upload initially failed. Once the server advertised the
correct object type, the client uploaded structurally valid but fully
transparent PNGs and the menu showed no badge.

The missing libScePngEnc HLE entry points blocked PNG export. With encoding
available, the CPU converter still read an unsynchronized guest buffer while
the rendered badge was held in the Vulkan texture cache. libpng correctly
encoded the zeroed pixels it received.

This change registers the four libScePngEnc functions and synchronizes the
Vulkan-backed tiled texture before the game's CPU conversion call site.
The game's existing converter still handles the layout. The hook checks the
game 1.28 instruction signature before patching. The opt-in diagnostic logs
source pixel counts and the encoded SHA-256 for comparison against uploads.

The full fix also needs the separate server changes. The client constructs
`CreateBobRequest.objectType = 5` from the advertised Protobuf descriptor.
The server needs to publish that enum value, save both uploaded BOB IDs,
and return the IDs and preview URLs in club metadata. The companion schema
and persistence patches target Judaswick/driveclub-server's `coop` branch.
They can be reviewed there independently.

In a real isolated Windows session with the patched client and server, saving
produced valid 256×256 and 64×64 PNGs with nontransparent pixels and matching
encoder, storage and download hashes. Badge previews were visible and the
user confirmed they persisted after restart. A fresh local build on upstream
v0.4.2 hotfix commit e9d32b8 compiled and passed a startup usage smoke test.
The reporter subsequently verified the deployed patch in the Windows v0.4.2
installation. Saving, the editor, car liveries and menu previews worked after
restart. The separate fresh build still needs an in-game test. The server
regression passed upload, metadata and restart checks. The readback hook
requires the matching game 1.28 signature. Linux remains untested.

The encoder is adapted from shadPS4 commit
[`4f11a8c`](https://github.com/shadps4-emu/shadPS4/commit/4f11a8c979de05cc97a236c2346c0f3343dc4034)
and retains the project's copyright and GPL-2.0-or-later notices.

Investigation and implementation were completed with assistance from OpenAI
Codex. Final behavior was validated in a real isolated game session.
