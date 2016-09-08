{lib, disnix, help2man, ...}:

lib.overrideDerivation disnix (o: {
  patches = [ ./armv7l.patch ./disnix-import-sudo.patch ./argument-list-too-long.patch ];
  buildInputs = o.buildInputs ++ [ help2man ];
})
