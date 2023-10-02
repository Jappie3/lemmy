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

    packages.x86_64-linux.lemmy-fail = pkgs.rustPlatform.buildRustPackage {
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
      cargoLock = {
        lockFile = ./Cargo.lock;
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

    packages.x86_64-linux.lemmy-ignore = pkgs.rustPlatform.buildRustPackage {
      name = "lemmy";
      pname = "lemmy";
      src = ./.;
      cargoLock = {
        lockFile = ./Cargo.lock;
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
        trivy --cache-dir .trivycache config --exit-code 0 .
      '';
      postBuild = ''
        cargo clippy -- -A clippy::all
      '';
    };

    packages.x86_64-linux.shorttest = pkgs.writeScript "testscript" ''
      #!${pkgs.runtimeShell}
      sleep 10
      echo 'hi'

      ${pkgs.jq}/bin/jq . "$HYDRA_JSON"
    '';

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

      runCommandHook = {
        # boolean not supported???
        # recurseForDerivations = true;

        # deploy = pkgs.writeScript "deploy-script" ''
        #   #!${pkgs.runtimeShell}

        #   ${pkgs.jq}/bin/jq . "$HYDRA_JSON"
        # '';

        "ignore" = self.packages.x86_64-linux.shorttest;
      };
    };
  };
}
