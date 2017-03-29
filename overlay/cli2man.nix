{python27Packages, fetchFromGitHub, lib}:

python27Packages.buildPythonPackage rec {
  name = "cli2man-0.2.3";
  src = fetchFromGitHub {
    owner = "rimmington";
    repo = "cli2man";
    rev = "3f4642d46290ef3fdab7e6b0a3fe5b8d69fa85da";
    sha256 = "1nvvl5c2nh8frwznvfkl4j850hffjka5cd5vc7rxlz5x0q7dka8q";
  };

  propagatedBuildInputs = with python27Packages; [ docopt ];

  meta = {
    homepage = https://github.com/rimmington/cli2man;
    description = "Converts the help message of a program into a manpage";
    license = lib.licenses.mit;
  };
}
