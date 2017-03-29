{lib, bundlerEnv, ruby}:

bundlerEnv rec {
  name = "ronn-${version}";
  version = "0.7.3";

  inherit ruby;
  gemfile = ./Gemfile;
  lockfile = ./Gemfile.lock;
  gemset = ./gemset.nix;
}
