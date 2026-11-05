{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    # the plugin directory, for programs.dux-shell.plugins.audigon.src
    packages = forAllSystems (pkgs: {
      default = pkgs.callPackage ./nix/package.nix {};
    });

    checks = forAllSystems (pkgs: {
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      lib = pkgs.runCommand "audigon-lib-tests" {nativeBuildInputs = [pkgs.nodejs];} ''
        mkdir plugin
        cp -r ${./plugin/lib} plugin/lib
        cp -r ${./tests} tests
        for test in tests/*.test.mjs; do
          node "$test"
        done
        touch $out
      '';
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.quickshell
          pkgs.qt6.qtdeclarative # qmllint, qmlformat
          pkgs.nodejs # lib/ tests
        ];
      };
    });

    formatter = forAllSystems (pkgs: pkgs.alejandra);
  };
}
