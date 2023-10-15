{
  description = "Lemmy flake for building on Hydra & deploying via Cachix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    cachix.url = "github:cachix/cachix";
    cachix-deploy-flake.url = "github:cachix/cachix-deploy-flake";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    cachix-deploy-flake,
    advisory-db,
    ...
  }: let
    inherit (self) inputs;
    system = "x86_64-linux";
    pkgs = import "${nixpkgs}" {
      inherit system;
      config.allowUnfree = true;
    };
    cachix-deploy-lib = cachix-deploy-flake.lib pkgs;
    translations-submodule = pkgs.stdenv.mkDerivation {
      name = "translations";
      src = fetchTarball {
        url = "https://github.com/LemmyNet/lemmy-translations/archive/1c42c579460871de7b4ea18e58dc25543b80d289.tar.gz";
        sha256 = "sha256:14nj3aj6avn3y0nqxfdrbgd7w5nii5zqzm4klhsslkfq6nczd4fs";
      };
      installPhase = ''
        mkdir $out
        cp -r email translations README.md translators.json LICENSE $out
      '';
    };
  in {
    packages."${system}" = {
      # DEPLOY HOST
      deploy = cachix-deploy-lib.spec {
        agents = {
          lemmy-deploy = cachix-deploy-lib.nixos {
            imports = [
              inputs.disko.nixosModules.disko
              inputs.agenix.nixosModules.default
              ./configuration.nix
            ];
          };
        };
      };

      # LEMMY PACKAGE - fix & fail
      lemmy-fix = pkgs.rustPlatform.buildRustPackage {
        name = "lemmy";
        pname = "lemmy";
        src = ./lemmy;
        cargoLock = {
          lockFile = ./lemmy/Cargo.lock;
        };
        doCheck = true;
        copyLibs = true;

        CARGO_BUILD_INCREMENTAL = "false";
        RUST_BACKTRACE = "full";

        nativeBuildInputs = with pkgs; [
          # build deps
          pkg-config
          rustfmt
          rustc
          cargo
          # SBOM
          cargo-cyclonedx
          # SCA (audit cargo.lock)
          cargo-audit
          # security scanner
          trivy
          # lints
          clippy
        ];
        buildInputs = with pkgs; [
          openssl.dev
          postgresql.lib
        ];

        preConfigure = ''
          # make sure the git submodule is in place
          mkdir -p crates/utils/translations
          cp -r ${translations-submodule}/* crates/utils/translations
        '';

        preBuild = ''
          cargo cyclonedx
          # needs internet V
          #cargo audit -n -d ${advisory-db} fix
          trivy --cache-dir .trivycache config .
        '';

        postBuild = ''
          cargo clippy --fix --allow-no-vcs
        '';
      };
      lemmy-fail = pkgs.rustPlatform.buildRustPackage {
        name = "lemmy";
        pname = "lemmy";
        src = ./lemmy;
        cargoLock = {
          lockFile = ./lemmy/Cargo.lock;
        };
        doCheck = true;
        copyLibs = true;

        CARGO_BUILD_INCREMENTAL = "false";
        RUST_BACKTRACE = "full";

        nativeBuildInputs = with pkgs; [
          # build deps
          pkg-config
          rustfmt
          rustc
          cargo
          # SBOM
          cargo-cyclonedx
          # SCA (audit cargo.lock)
          cargo-audit
          # security scanner
          trivy
          # lints
          clippy
        ];
        buildInputs = with pkgs; [
          openssl.dev
          postgresql.lib
        ];

        preConfigure = ''
          # make sure the git submodule is in place
          mkdir -p crates/utils/translations
          cp -r ${translations-submodule}/* crates/utils/translations
        '';

        preBuild = ''
          cargo cyclonedx
          # fail on warnings:
          cargo audit -n -d ${advisory-db} --deny warnings
          trivy --cache-dir .trivycache config --exit-code 1 .
        '';

        postBuild = ''
          # fail on warnings
          cargo clippy -- -D warnings
        '';
      };
    };

    # HYDRA JOBS
    hydraJobs = {
      fix = self.packages."${system}".lemmy-fix;
      fail = self.packages."${system}".lemmy-fail;
      deploy = self.packages."${system}".deploy;
    };
  };
}
