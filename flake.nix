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
    packages.x86_64-linux.buildlemmy = pkgs.rustPlatform.buildRustPackage {
      # TODO
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
      copyLibs = true;

      # set env vars
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

        cargo audit
        # cargo audit fix

        # TODO look into workspace-inheritance feature
        #cargo cyclonedx

        trivy config .
        trivy filesystem .
      '';

      postConfigure = ''
        cargo clippy
        # cargo clippy --fix
      '';
    };

    hydraJobs."main" = {
      job = self.packages.x86_64-linux.buildlemmy;
    };
  };
}
