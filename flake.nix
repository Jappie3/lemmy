{
  description = "Rust Hello World program for testing Hydra";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    advisory-db,
    ...
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
    # TODO
    # format with cargo: +nightly fmt --all
    # run linter: ./scripts/fix-clippy.sh

    packages.x86_64-linux.lemmy-fix = pkgs.rustPlatform.buildRustPackage {
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
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

        cargo cyclonedx
        cargo audit fix
        trivy --cache-dir .trivycache config .
      '';

      postConfigure = ''
        cargo clippy
        # cargo clippy --fix
        # cargo clippy -D warnings -> fails on warnings
      '';
    };

    packages.x86_64-linux.lemmy-fail = pkgs.rustPlatform.buildRustPackage {
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
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

        cargo cyclonedx
        #cargo audit -n -d ${advisory-db}
        # cargo audit fix
        trivy --cache-dir .trivycache config .
      '';

      postConfigure = ''
        cargo clippy
        # cargo clippy --fix
        # cargo clippy -D warnings -> fails on warnings
      '';
    };

    packages.x86_64-linux.lemmy-ignore = pkgs.rustPlatform.buildRustPackage {
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
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

        cargo cyclonedx
        #cargo audit -n -d ${advisory-db}
        # cargo audit fix
        trivy --cache-dir .trivycache config .
      '';

      postConfigure = ''
        cargo clippy
        # cargo clippy --fix
        # cargo clippy -D warnings -> fails on warnings
      '';
    };

    hydraJobs = {
      "fix" = {
        job = self.packages.x86_64-linux.lemmy-fix;
      };
      "fail" = {
        job = self.packages.x86_64-linux.lemmy-fail;
      };
      "ignore" = {
        job = self.packages.x86_64-linux.lemmy-ignore;
      };
    };
  };
}
