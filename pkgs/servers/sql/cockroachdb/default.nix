# https://www.cockroachlabs.com/docs/releases/release-support-policy.html

{ callPackage }: {
  # Maintenance Support Ends: 2021-11-10
  # EOL: 2022-05-10
  cockroachdb_20_2 = callPackage ./generic.nix {
    version = "20.2.18";
    sha256 = "sha256-FHvVjoHkKKXDeN/H5J8vclA8/H9A4GYlfjFI+pXeTC8=";
  };

  # Maintenance Support Ends: 2022-05-18
  # EOL: 2022-11-18
  cockroachdb_21_1 = callPackage ./generic.nix {
    version = "21.1.13";
    sha256 = "sha256-gznglQKRJqPPJMlN9v/IYM78WP5KqOEuoAW4scmKScg=";
  };

  # Maintenance Support Ends: 2022-11-16
  # EOL: 2023-05-16
  cockroachdb_21_2 = callPackage ./generic.nix {
    version = "21.2.4";
    sha256 = "0ns73q1iryzsca4l1m7183s4zgv3hicawnc5hbfkp0w4c9jh58xm";
    patches = [ ./remove_make_flags.patch ./yarn-offline.diff ];
  };
}
