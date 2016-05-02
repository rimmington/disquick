{lib, dysnomia}:

lib.overrideDerivation dysnomia (o: { configureFlags = o.configureFlags ++ [ "--with-systemd-rundir=/etc/systemd" "--with-systemd-path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" ]; })
