{lib, dysnomia}:

lib.overrideDerivation dysnomia (oldAttrs: {
  configureFlags = oldAttrs.configureFlags ++ [ "--with-systemd-rundir=/etc/systemd" "--with-systemd-path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ];
  patches = [ ./systemd-enable.patch ];
})
