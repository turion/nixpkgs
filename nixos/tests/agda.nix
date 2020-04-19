import ./make-test-python.nix ({ pkgs, ... }:

let
  testfile = pkgs.writeText "TestModule.agda"
    ''
    module TestModule
    import IO
    '';
  mylibFile = pkgs.writeText "mylib.agda-lib"
    ''
    name: mylib
    include: src
    '';
in
{
  name = "agda";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ alexarice turion ];
  };

  machine = { pkgs, ... }: {
    environment.systemPackages = [
      (pkgs.agda.withPackages {
        pkgs = [pkgs.agda.standard-library];
        homeLibraries = "mylib/mylib.agda-lib";
      })
    ];
    virtualisation.memorySize = 1000; # Agda uses a lot of memory
  };

  testScript = ''
    # Minimal user library
    machine.succeed("mkdir -p mylib/src")
    machine.succeed(
        "cp ${testfile} mylib/src/TestModule.agda"
    )
    machine.succeed(
        "cp ${mylibFile} mylib/mylib.agda-lib"
    )
    print(machine.succeed("ls -la mylib/"))
    machine.succeed('echo "import TestModule" > TestUserLibrary.agda')
    machine.succeed("agda -l standard-library -l mylib -i . TestUserLibrary.agda")

    # Minimal script that typechecks
    machine.succeed("touch TestEmpty.agda")
    machine.succeed("agda -l standard-library -i . TestEmpty.agda")

    # Minimal script that actually uses the standard library
    machine.succeed('echo "import IO" > TestIO.agda')
    machine.succeed("agda -l standard-library -i . TestIO.agda")
  '';
}
)
