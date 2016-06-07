{python27Packages, fetchFromGitHub, lib}:

python27Packages.buildPythonPackage rec {
  name = "cli2man-0.2.3";
  src = fetchFromGitHub {
    owner = "rimmington";
    repo = "cli2man";
    rev = "184f75621e660c7d91f1ee379b0a453f03806e15";
    sha256 = "19xnxlpy2f1wav9pqqvbmbxvmvk8qr563ngcpxp9bh5n6w20fqah";
  };

  propagatedBuildInputs = with python27Packages; [ docopt ];

  meta = {
    homepage = https://github.com/rimmington/cli2man;
    description = "Converts the help message of a program into a manpage";
    license = lib.licenses.mit;
  };
}
