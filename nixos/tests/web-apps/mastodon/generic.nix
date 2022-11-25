pkgs:

let
  cert = pkgs: pkgs.runCommand "selfSignedCerts" { buildInputs = [ pkgs.openssl ]; } ''
    openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -nodes -subj '/CN=mastodon.local' -days 36500
    mkdir -p $out
    cp key.pem cert.pem $out
  '';

  mkTest =
    { pkgs
    , nodes
    , hosts
    , extraInit ? ""
    , extraShutdown ? ""
    }:

    {
      name = "mastodon";
      meta.maintainers = with pkgs.lib.maintainers; [ erictapen izorkin turion ];

      nodes = nodes // {
        client = { pkgs, ... }: {
          environment.systemPackages = [ pkgs.jq ];
          networking = {
            interfaces.eth1 = {
              ipv4.addresses = [
                { address = "192.168.2.202"; prefixLength = 24; }
              ];
            };
            extraHosts = hosts;
          };

          security = {
            pki.certificateFiles = [ "${cert pkgs}/cert.pem" ];
          };
        };
      };

      testScript = import ./script.nix {
        inherit
          pkgs
          extraInit
          extraShutdown
        ;
      };
    };
in
needsEnv: mkTest (needsEnv { inherit cert; })
