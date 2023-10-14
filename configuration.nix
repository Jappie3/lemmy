{
  config,
  inputs,
  lib,
  pkgs,
  modulesPath,
  ...
}: let
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
  # Cachix token for deploying the agent
  age.secrets.cachix-agent.file = ./secrets/cachix-agent.age;

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  disko.devices = import ./disko.nix "/dev/sda";

  networking.hostName = "lemmy-deploy";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  time.timeZone = "Europe/Brussels";

  nix = {
    package = pkgs.nixUnstable;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      sandbox = true;
      keep-outputs = true;
      keep-derivations = true;
      log-lines = 25;
      warn-dirty = false;
    };
  };

  boot = {
    tmp.cleanOnBoot = true;
    consoleLogLevel = 0;
    loader.grub = {
      devices = ["/dev/sda"];
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
  };

  services = {
    cachix-agent = {
      enable = true;
      name = "lemmy-deploy";
      # host = "jappie3.cachix.org";
      credentialsFile = "${config.age.secrets.cachix-agent.path}";
    };
    lemmy = {
      enable = true;
      settings = {
        port = 8536;
        # domain name of the instance
        hostname = "lemmy.zephyo.me";
      };
      server.package = pkgs.rustPlatform.buildRustPackage {
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
          trivy --cache-dir .trivycache config --exit-code 0 .
        '';
        postBuild = ''
          cargo clippy -- -A clippy::all
        '';
      };
      # database = {
      #   uri = "";
      # };
      ui = {
        # package =
        port = 1234;
      };
    };
    postgresql = {
      # https://pgtune.leopard.in.ua/
      enable = true;
      port = 5432;
      # allow all local connections, type database user address method
      # don't do this in production, use passwords (:
      authentication = ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
    };
    openssh = {
      enable = true;
      startWhenNeeded = true;
      ports = [22];
      openFirewall = true;
      banner = "\n\tThe great gates have been sealed.\n\t\tNone shall enter.\n\t\tNone shall leave.\n\n\n";
      settings = {
        X11Forwarding = false;
        UseDns = false;
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
          "sntrup761x25519-sha512@openssh.com"
        ];
      };
    };
  };

  programs.ssh = {
    knownHosts = {
      github-ed25519.hostNames = ["github.com"];
      github-ed25519.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      gitlab-ed25519.hostNames = ["gitlab.com"];
      gitlab-ed25519.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf";
      codeberg-ed25519.hostNames = ["codeberg.org"];
      codeberg-ed25519.publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVIC02vnjFyL+I4RHfvIGNtOgJMe769VTF1VR4EB3ZB";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA1mAN5Db7eZ0iuBGGxdPqQCR2l6jDZBjgX4ZVOcip27 jasper@Kainas"
  ];

  environment.systemPackages = with pkgs; [
    tree
    jq
    cachix
    # lemmy-server -> comes from Cachix
    lemmy-ui
    postgresql
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
