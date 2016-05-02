{lib, disnix, help2man, ...}:

lib.overrideDerivation disnix (o: {
  patches = [ ./armv7l.patch ./disnix-import-sudo.patch ];
  buildInputs = o.buildInputs ++ [ help2man ];
})
