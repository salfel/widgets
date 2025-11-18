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

          src = ./.;

          nativeBuildInputs = with pkgs; [
            (odin.overrideAttrs (old: rec {
              version = "dev-2025-11";
              src = fetchFromGitHub {
                owner = "odin-lang";
                repo = "Odin";
                tag = version;
                hash = "sha256-Nyi8/52xexGPSnWIF8eMSMqaXFQD57dDRGl6IuZcppw=";
              };
            }))
          ];

          buildInputs = with pkgs; [
            libGL
            wayland
            libxkbcommon
          ];

          buildPhase = ''
            odin build src --out:${name} -collection:lib=lib
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp ${name} $out/bin
          '';
        };
      }
    );
}
