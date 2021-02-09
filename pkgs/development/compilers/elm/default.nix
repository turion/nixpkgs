{ lib, stdenv, pkgs
, haskell, nodejs
, fetchurl, fetchpatch, makeWrapper, writeScriptBin
  # Rust dependecies
, rustPlatform, openssl, pkg-config, Security
}:
let
  fetchElmDeps = import ./fetchElmDeps.nix { inherit stdenv lib fetchurl; };

  hsPkgs = haskell.packages.ghc8103.override {
    overrides = self: super: with haskell.lib; with lib;
      let elmPkgs = rec {
            elm = overrideCabal (self.callPackage ./packages/elm.nix { }) (drv: {
              # sadly with parallelism most of the time breaks compilation
              enableParallelBuilding = false;
              preConfigure = self.fetchElmDeps {
                elmPackages = (import ./packages/elm-srcs.nix);
                elmVersion = drv.version;
                registryDat = ./registry.dat;
              };
              buildTools = drv.buildTools or [] ++ [ makeWrapper ];
              jailbreak = true;
              postInstall = ''
                wrapProgram $out/bin/elm \
                  --prefix PATH ':' ${lib.makeBinPath [ nodejs ]}
              '';

              description = "A delightful language for reliable webapps";
              homepage = "https://elm-lang.org/";
              license = licenses.bsd3;
              maintainers = with maintainers; [ domenkozar turbomack ];
            });

            /*
            The elm-format expression is updated via a script in the https://github.com/avh4/elm-format repo:
            `package/nix/build.sh`
            */
            elm-format = justStaticExecutables (overrideCabal (self.callPackage ./packages/elm-format.nix {}) (drv: {
              jailbreak = true;

              description = "Formats Elm source code according to a standard set of rules based on the official Elm Style Guide";
              homepage = "https://github.com/avh4/elm-format";
              license = licenses.bsd3;
              maintainers = with maintainers; [ avh4 turbomack ];
            }));

            elmi-to-json = justStaticExecutables (overrideCabal (self.callPackage ./packages/elmi-to-json.nix {}) (drv: {
              prePatch = ''
                substituteInPlace package.yaml --replace "- -Werror" ""
                hpack
              '';
              jailbreak = true;

              description = "Tool that reads .elmi files (Elm interface file) generated by the elm compiler";
              homepage = "https://github.com/stoeffel/elmi-to-json";
              license = licenses.bsd3;
              maintainers = [ maintainers.turbomack ];
            }));

            elm-instrument = justStaticExecutables (overrideCabal (self.callPackage ./packages/elm-instrument.nix {}) (drv: {
              prePatch = ''
                sed "s/desc <-.*/let desc = \"${drv.version}\"/g" Setup.hs --in-place
              '';
              jailbreak = true;
              # Tests are failing because of missing instances for Eq and Show type classes
              doCheck = false;

              description = "Instrument Elm code as a preprocessing step for elm-coverage";
              homepage = "https://github.com/zwilias/elm-instrument";
              license = licenses.bsd3;
              maintainers = [ maintainers.turbomack ];
            }));

            inherit fetchElmDeps;
            elmVersion = elmPkgs.elm.version;
          };
      in elmPkgs // {
        inherit elmPkgs;

        # Needed for elm-format
        indents = self.callPackage ./packages/indents.nix {};
        bimap = self.callPackage ./packages/bimap.nix {};
        avh4-lib = self.callPackage ./packages/avh4-lib.nix {};
        elm-format-lib = self.callPackage ./packages/elm-format-lib.nix {};
        elm-format-test-lib = self.callPackage ./packages/elm-format-test-lib.nix {};
        elm-format-markdown = self.callPackage ./packages/elm-format-markdown.nix {};
      };
  };

  /* Node/NPM based dependecies can be upgraded using script `packages/generate-node-packages.sh`.

      * Packages which rely on `bin-wrap` will fail by default
        and can be patched using `patchBinwrap` function defined in `packages/lib.nix`.

      * Packages which depend on npm installation of elm can be patched using
        `patchNpmElm` function also defined in `packages/lib.nix`.
  */
  elmLib = import ./packages/lib.nix {
    inherit lib writeScriptBin stdenv;
    inherit (hsPkgs.elmPkgs) elm;
  };

  elmRustPackages =  {
    elm-json = import ./packages/elm-json.nix {
      inherit lib rustPlatform fetchurl openssl stdenv pkg-config Security;
    } // {
      meta = with lib; {
        description = "Install, upgrade and uninstall Elm dependencies";
        homepage = "https://github.com/zwilias/elm-json";
        license = licenses.mit;
        maintainers = [ maintainers.turbomack ];
        platforms = platforms.linux;
      };
    };
  };

  elmNodePackages = with elmLib;
    let
      nodePkgs = import ./packages/node-composition.nix {
          inherit nodejs pkgs;
          inherit (stdenv.hostPlatform) system;
        };
    in with hsPkgs.elmPkgs; {

      elm-test = patchBinwrap [elmi-to-json]
        nodePkgs.elm-test // {
          meta = with lib; {
            description = "Runs elm-test suites from Node.js";
            homepage = "https://github.com/rtfeldman/node-test-runner";
            license = licenses.bsd3;
            maintainers = [ maintainers.turbomack ];
          };
        };

      elm-verify-examples = patchBinwrap [elmi-to-json]
        nodePkgs.elm-verify-examples // {
          meta = with lib; {
            description = "Verify examples in your docs";
            homepage = "https://github.com/stoeffel/elm-verify-examples";
            license = licenses.bsd3;
            maintainers = [ maintainers.turbomack ];
          };
        };

      elm-coverage =
        let patched = patchNpmElm (patchBinwrap [elmi-to-json] nodePkgs.elm-coverage);
        in patched.override (old: {
          # Symlink Elm instrument binary
          preRebuild = (old.preRebuild or "") + ''
            # Noop custom installation script
            sed 's/\"install\".*/\"install\":\"echo no-op\"/g' --in-place package.json

            # This should not be needed (thanks to binwrap* being nooped) but for some reason it still needs to be done
            # in case of just this package
            # TODO: investigate
            sed 's/\"install\".*/\"install\":\"echo no-op\",/g' --in-place node_modules/elmi-to-json/package.json
          '';
          postInstall = (old.postInstall or "") + ''
            mkdir -p unpacked_bin
            ln -sf ${elm-instrument}/bin/elm-instrument unpacked_bin/elm-instrument
          '';
          meta = with lib; {
            description = "Work in progress - Code coverage tooling for Elm";
            homepage = "https://github.com/zwilias/elm-coverage";
            license = licenses.bsd3;
            maintainers = [ maintainers.turbomack ];
          };
        });

      create-elm-app = patchNpmElm (patchBinwrap [elmi-to-json]
        nodePkgs.create-elm-app) // {
          meta = with lib; {
            description = "Create Elm apps with no build configuration";
            homepage = "https://github.com/halfzebra/create-elm-app";
            license = licenses.mit;
            maintainers = [ maintainers.turbomack ];
          };
        };

      elm-review = patchBinwrap [elmRustPackages.elm-json]
        nodePkgs.elm-review // {
          meta = with lib; {
            description = "Analyzes Elm projects, to help find mistakes before your users find them";
            homepage = "https://package.elm-lang.org/packages/jfmengels/elm-review/${nodePkgs.elm-review.version}";
            license = licenses.bsd3;
            maintainers = [ maintainers.turbomack ];
          };
        };

      elm-language-server = nodePkgs."@elm-tooling/elm-language-server" // {
        meta = with lib; {
          description = "Language server implementation for Elm";
          homepage = "https://github.com/elm-tooling/elm-language-server";
          license = licenses.mit;
          maintainers = [ maintainers.turbomack ];
        };
      };

      elm-optimize-level-2 = nodePkgs."elm-optimize-level-2" // {
        meta = with lib; {
          description = "A second level of optimization for the Javascript that the Elm Compiler produces";
          homepage = "https://github.com/mdgriffith/elm-optimize-level-2";
          license = licenses.bsd3;
          maintainers = [ maintainers.turbomack ];
        };
      };

      inherit (nodePkgs) elm-doc-preview elm-live elm-upgrade elm-xref elm-analyse;
    };

in hsPkgs.elmPkgs // elmNodePackages // elmRustPackages // {
  lib = elmLib;
}
