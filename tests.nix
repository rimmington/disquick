with import ./default.nix {};

let
  s1 = mkService {
    name = "s1";
    user = {
      name = "bob";
      home = "/home/bob";
    };
    script = "true";
  };
  s2 = mkService {
    name = "s2";
    user = {
      name = "bob";
      home = "/var/lib/bob";
    };
    script = "true";
  };
  s3 = mkService {
    name = "s3";
    user.name = "alice";
    script = "true";
  };
  s4 = mkService {
    name = "s4";
    user.name = "alice";
    script = "true";
  };
in
  assert (builtins.tryEval (checkServices { inherit s1; })).success == true;
  assert (builtins.tryEval (checkServices { inherit s1 s2; })).success == false;
  assert (builtins.tryEval (checkServices { inherit s1 s3; })).success == true;
  assert (builtins.tryEval (checkServices { inherit s3 s4; })).success == true;
  true
