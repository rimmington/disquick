{writeText, lib, stdenv, pkgs, disnix, libxslt}:
{serviceSet, hostname, system}:

let
  disnixLib = import "${disnix}/share/disnix/lib.nix" { nixpkgs = <nixpkgs>; inherit pkgs; };
  viaXSLT = name: xsl: attrset: stdenv.mkDerivation {
    inherit name;
    xml = builtins.toXML attrset;
    passAsFile = [ "xml" ];
    buildCommand = "${libxslt.bin}/bin/xsltproc ${xsl} $xmlPath > $out";
  };
  infrastructure = { target = { inherit hostname system; }; };
  servicesFun = {system, pkgs, distribution, invDistribution}: pkgs.lib.mapAttrs' (name: s: { name = s.attrs.name; value = s.disnix; }) serviceSet;
  distributionFun = {infrastructure}: lib.mapAttrs' (name: s: { name = s.attrs.name; value = builtins.attrValues infrastructure; }) serviceSet;
  targetProperty = "hostname";
  clientInterface = "disnix-ssh-client";
in {
  inherit infrastructure;
  manifest = viaXSLT "manifest.xml" "${disnix}/share/disnix/generatemanifest.xsl" (disnixLib.generateManifest pkgs servicesFun infrastructure distributionFun targetProperty clientInterface false);
  distributedDerivation = viaXSLT "distributedDerivation.xml" "${disnix}/share/disnix/generatedistributedderivation.xsl" (disnixLib.generateDistributedDerivation servicesFun infrastructure distributionFun targetProperty clientInterface);
}
