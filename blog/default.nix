{lib, makeWrapper, stdenv, bundlerEnv, ruby, bundler, coreutils, dataDir ? "/var/lib/rails-test"}@args:

let
  env = bundlerEnv {
    name = "rails-test-gems";

    inherit ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in stdenv.mkDerivation rec {
  name = "rails-test";
  src = ./.;

  bundler = args.bundler.override { inherit ruby; };

  buildInputs = [ makeWrapper ruby bundler ];

  setSourceRoot = ''
    mkdir -p $out/share/${name}
    find ./blog -mindepth 1 -maxdepth 1 ! -name '.bundle' | xargs -I '{}' cp -R {} $out/share/${name}
    export sourceRoot="$out/share/${name}"
  '';

  buildPhase = ''
    export HOME=$PWD
    export GEM_HOME=${env}/${env.ruby.gemPath}
    rm -rf ./bin
    ${env}/bin/bundle exec rake rails:update:bin
  '';

  installPhase = ''
    rm -rf log tmp db
    ln -sf ${dataDir}/{db,state/log,state/tmp} .

    mkdir -p $out/bin
    makeWrapper bin/bundle "$out/bin/bundle" \
      --run "cd $sourceRoot" \
      --prefix "PATH" : "$sourceRoot/bin:${env.ruby}/bin:$PATH" \
      --set "HOME" "$sourceRoot" \
      --prefix "GEM_HOME" : "${env}/${env.ruby.gemPath}" \
      --prefix "GEM_PATH" : "$sourceRoot:${bundler}/${env.ruby.gemPath}"

    makeWrapper $out/bin/bundle $out/bin/rails-test \
      --run "${coreutils}/bin/mkdir -p ${dataDir}/{db,state/log,state/tmp}" \
      --set RAILS_ENV development \
      --add-flags 'exec rails server'
  '';
}
