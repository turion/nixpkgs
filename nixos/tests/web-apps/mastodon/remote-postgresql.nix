import ../../make-test-python.nix ({pkgs, ...}:
let
  hosts = ''
    192.168.2.101 mastodon.local
  '';
in
import ./generic.nix pkgs ({ cert }: {
  inherit pkgs hosts;

  nodes = {
    database = {
      networking = {
        interfaces.eth1 = {
          ipv4.addresses = [
            { address = "192.168.2.102"; prefixLength = 24; }
          ];
        };
        extraHosts = hosts;
        firewall.allowedTCPPorts = [ 5432 ];
      };

      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = ''
          hostnossl mastodon_local mastodon_test 192.168.2.201/32 md5
        '';
        initialScript = pkgs.writeText "postgresql_init.sql" ''
          CREATE ROLE mastodon_test LOGIN PASSWORD 'SoDTZcISc3f1M1LJsRLT';
          CREATE DATABASE mastodon_local TEMPLATE template0 ENCODING UTF8;
          GRANT ALL PRIVILEGES ON DATABASE mastodon_local TO mastodon_test;
        '';
      };
    };

    nginx = {
      networking = {
        interfaces.eth1 = {
          ipv4.addresses = [
            { address = "192.168.2.101"; prefixLength = 24; }
          ];
        };
        extraHosts = hosts;
        firewall.allowedTCPPorts = [ 80 443 ];
      };

      security = {
        pki.certificateFiles = [ "${cert pkgs}/cert.pem" ];
      };

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        virtualHosts."mastodon.local" = {
          root = "/var/empty";
          forceSSL = true;
          enableACME = pkgs.lib.mkForce false;
          sslCertificate = "${cert pkgs}/cert.pem";
          sslCertificateKey = "${cert pkgs}/key.pem";
          locations."/" = {
            tryFiles = "$uri @proxy";
          };
          locations."@proxy" = {
            proxyPass = "http://192.168.2.201:55001";
            proxyWebsockets = true;
          };
          locations."/api/v1/streaming/" = {
            proxyPass = "http://192.168.2.201:55002/";
            proxyWebsockets = true;
          };
        };
      };
    };

    server = {
      imports = [
        (import ./common/server.nix { inherit hosts cert; })
      ];

      environment = {
        etc = {
          "mastodon/password-posgresql-db".text = ''
            SoDTZcISc3f1M1LJsRLT
          '';
        };
      };

      networking = {
        firewall.allowedTCPPorts = [ 55001 55002 ];
      };

      services.mastodon = {
        database = {
          createLocally = false;
          host = "192.168.2.102";
          port = 5432;
          name = "mastodon_local";
          user = "mastodon_test";
          passwordFile = "/etc/mastodon/password-posgresql-db";
        };
        extraConfig = {
          BIND = "0.0.0.0";
          RAILS_SERVE_STATIC_FILES = "true";
          TRUSTED_PROXY_IP = "192.168.2.101";
        };
      };
    };
  };

  extraInit = ''
    nginx.wait_for_unit("nginx.service")
    database.wait_for_unit("postgresql.service")
    database.wait_for_open_port(5432)
    server.wait_for_open_port(55000)
    server.wait_for_open_port(55001)
  '';

  extraShutdown = ''
    database.shutdown()
    nginx.shutdown()
  '';
}))
