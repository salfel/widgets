{
  description = "Widgets library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        packages.default = pkgs.stdenv.mkDerivation rec {
          name = "widgets";

          src = ./src;

          buildInputs = with pkgs; [
            odin
            glfw
          ];

          buildPhase = ''
            odin build . --out:${name}
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp ${name} $out/bin
          '';
        };
      }
    );
}
