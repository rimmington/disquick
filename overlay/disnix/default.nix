{lib, disnix, help2man, ...}:

lib.overrideDerivation disnix (o: {
  patches = [ ./disnix-import-sudo.patch ./argument-list-too-long.patch ./send-outputs.patch ];
  buildInputs = o.buildInputs ++ [ help2man ];
})
