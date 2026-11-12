Persist Club Badge upload IDs and advertise the badge object type

DriveClub 1.28 builds its upload request using the EGS descriptor. A server
without `BobObjectType = 5` leaves the game with a null enum descriptor.
A server that discards the resulting BOB IDs cannot return usable badge
preview URLs when the player opens the club menu again.

Advertise enum value 5 and retain both badge IDs in the existing club
customization JSON. Return their URLs when requested and use the server's
current public base URL. Existing clubs without badge references keep
working and need no migration.

The regression covers the advertised descriptor, both image sizes, two
consecutive badge updates, preservation across livery-only changes, byte
integrity, and server restart. The companion client fix was verified in a
real isolated Windows game session with these server changes. The reporter
also verified saving, menu previews and persistence in the deployed Windows
DriveClub Recomp v0.4.2 setup. The client still needs PNG HLE and Vulkan
readback before CPU conversion to supply visible pixels for these URLs.

Investigation and implementation were completed with assistance from OpenAI Codex.
