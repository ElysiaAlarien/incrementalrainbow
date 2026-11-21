# The export code is the deflated save in base64, with a version and a checksum

The player moves a game between devices with an export code: text to copy on one device and paste on another. The code is `IR<version>.<payload>.<checksum>`:

- The version is the save version (ADR-0009). It is outside the payload, so a code from a newer game fails with a clear message before the import reads the payload.
- The payload is the save text of `SaveCodec.encode`, compressed with deflate and written in base64. It is the same save as on the device, not a second format, so an import uses the same migrations and the same strict load. Deflate makes the code much shorter, and base64 survives copy and paste in any text field.
- The checksum is the first 8 hex digits of the SHA-256 of the text before it. A typo or a code that is cut off fails before the import reads the payload. The checksum is not a protection against a player who edits the save on purpose: the save is not secret, and the strict load checks each value.

An import ignores spaces and line breaks, because messaging apps and text fields add them. It decompresses at most 16 MiB, so a hostile code cannot use all the memory of the device. Like a load, an import makes a new simulation, so a code that fails cannot change the current game. The UI asks the player to confirm before the game in a code replaces the current game.

We rejected a code with its own version number for the code format. The prefix `IR` names the format. If the format must change, a new prefix can name the new format, and the save version stays the only version.
