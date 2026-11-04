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
      mixer = pkgs.runCommand "audigon-mixer-test" {nativeBuildInputs = [pkgs.nodejs];} ''
        mkdir -p plugin/lib tests
        cp ${./plugin/lib/mixer.js} plugin/lib/mixer.js
        cp ${./tests/mixer.test.mjs} tests/mixer.test.mjs
        node tests/mixer.test.mjs
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
