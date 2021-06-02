{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/release-21.05;

  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
  in {
    overlay = prev: final: {
      seafoam = final.bundlerApp {
        pname = "seafoam";
        gemfile = ./Gemfile;
        lockfile = ./Gemfile.lock;
        gemset = ./gemset.nix;
        exes = ["seafoam"];
        buildInputs = [final.makeWrapper];
        postBuild = "wrapProgram $out/bin/seafoam --prefix PATH : ${final.lib.makeBinPath [ final.graphviz ]}";
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
