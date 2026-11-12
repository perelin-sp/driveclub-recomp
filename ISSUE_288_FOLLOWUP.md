Fixed locally and verified in my Windows DriveClub Recomp v0.4.2 installation
with DriveClub 1.28. Saving works, both PNG sizes contain visible badge
pixels, and the badge appears in the editor, on cars and in menu previews
after a restart.

The client adds PNG encoding and synchronizes the rendered badge before CPU
conversion. The companion server patch advertises object type 5 and persists
both preview references.

- Client: [branch URL] · [PR URL]
- Server: [branch URL] · [PR URL]
