import ../../make-test-python.nix ({pkgs, ...}:
let
  hosts = ''
    192.168.2.201 mastodon.local
  '';
in
import ./generic.nix pkgs ({ cert }: {
  inherit pkgs hosts;

  nodes = {
    server = {
      imports = [
        (import ./common/server.nix { inherit hosts cert; })
      ];

      services.mastodon.configureNginx = true;

      services.nginx = {
        virtualHosts."mastodon.local" = {
          enableACME = pkgs.lib.mkForce false;
          sslCertificate = "${cert pkgs}/cert.pem";
          sslCertificateKey = "${cert pkgs}/key.pem";
        };
      };
    };
  };

  extraInit = ''
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("postgresql.service")
    server.wait_for_open_port(443)
    server.wait_for_open_port(5432)
  '';
}))
