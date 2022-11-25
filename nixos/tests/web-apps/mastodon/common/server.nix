{ hosts, cert }: { pkgs, ... }: {
  virtualisation.memorySize = 2048;

  networking = {
    interfaces.eth1 = {
      ipv4.addresses = [
        { address = "192.168.2.201"; prefixLength = 24; }
      ];
    };
    extraHosts = hosts;
    firewall.allowedTCPPorts = [ 80 443 ];
  };

  security = {
    pki.certificateFiles = [ "${cert pkgs}/cert.pem" ];
  };

  services.mastodon = {
    enable = true;
    localDomain = "mastodon.local";
    smtp = {
      fromAddress = "mastodon@mastodon.local";
    };
    extraConfig = {
      EMAIL_DOMAIN_ALLOWLIST = "example.com";
    };
  };
}
