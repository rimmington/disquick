{pkgs, infrastructure}:

pkgs.checkServices {
  hello = pkgs.mkService {
    name = "hello";
    script = "${pkgs.hello}/bin/hello";
    user.name = "root";
  };
}
