{
  description = "Rust Hello World program for testing Hydra";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
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
    #nix.allowed-uris = "https://github.com/LemmyNet/lemmy-translations";
    packages.x86_64-linux.default = pkgs.rustPlatform.buildRustPackage {
      # format with cargo: +nightly fmt --all
      # run linter: ./scripts/fix-clippy.sh
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
      # dontUnpack = true;
      cargoLock = {
        lockFile = ./Cargo.lock;
      };
      doCheck = true;
      CARGO_BUILD_INCREMENTAL = "false";
      RUST_BACKTRACE = "full";
      copyLibs = true;
      nativeBuildInputs = with pkgs; [
        pkg-config
        rustfmt
        rustc
        cargo
      ];
      buildInputs = with pkgs; [
        openssl.dev
        postgresql.lib
      ];
      preConfigure = ''
        mkdir -p crates/utils/translations
        cp -r ${translations-submodule}/* crates/utils/translations
      '';
    };

    hydraJobs."main" = {
      job = self.packages.x86_64-linux.default;
    };
  };
}
