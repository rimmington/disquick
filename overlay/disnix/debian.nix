{lib, disnix, dysnomiaDebian, help2man}:

lib.overrideDerivation (disnix.override { dysnomia = dysnomiaDebian; }) (o: {
  postInstall = (o.postInstall or "") + ''
    substitute ${./disnix.service.in} $out/share/disnix/disnix.service \
      --replace @dysnomia@ ${dysnomiaDebian} \
      --replace @disnix@ $out
  '';
})