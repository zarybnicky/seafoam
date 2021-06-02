{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/release-21.05;

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
  in {
    overlay = prev: final: {
      seafoam = final.stdenv.mkDerivation rec {
        name = "${pname}-${version}";
        pname = "seafoam";
        version = (import ./gemset.nix).seafoam.version;
        env = final.bundlerEnv {
          pname = "seafoam";
          gemdir = ./.;
          exes = ["seafoam"];
        };
        nativeBuildInputs = [ final.makeWrapper ];
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/bin
          makeWrapper ${env}/bin/seafoam $out/bin/seafoam --prefix PATH : ${final.lib.makeBinPath [ final.graphviz ]}
        '';
      };
    };
    packages.x86_64-linux = { inherit (pkgs) seafoam; };

    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = [
        pkgs.ruby.devEnv
        pkgs.bundix
      ];
    };
  };
}
