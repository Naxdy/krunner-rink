{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    fenix.url = "github:nix-community/fenix";

    crane.url = "github:ipetkov/crane";

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      crane,
      treefmt-nix,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ fenix.overlays.default ];
            };

            rustToolchain = pkgs.fenix.stable.withComponents [
              "cargo"
              "rustc"
              "rustfmt"
              "rust-std"
              "rust-analyzer"
              "clippy"
            ];

            # more info on https://crane.dev/API.html
            craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

            cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);

            sharedEnv = {
              DBUS_SERVICE = cargoToml.package.metadata.krunner.service;
              DBUS_PATH = cargoToml.package.metadata.krunner.path;
            };

            craneArgs = {
              pname = cargoToml.workspace.package.name or cargoToml.package.name;
              version = cargoToml.workspace.package.version or cargoToml.package.version;

              src = craneLib.cleanCargoSource ./.;

              strictDeps = true;

              nativeBuildInputs = [
                pkgs.pkg-config
              ];

              buildInputs = [
                pkgs.dbus
                pkgs.openssl
              ];

              # can add `nativeBuildInputs` or `buildInputs` here

              env = {
                # print backtrace on compilation failure
                RUST_BACKTRACE = "1";

                # treat warnings as errors
                RUSTFLAGS = "-Dwarnings";
                RUSTDOCFLAGS = "-Dwarnings";
              } // sharedEnv;
            };

            cargoArtifacts = craneLib.buildDepsOnly craneArgs;

            craneBuildArgs = craneArgs // {
              src = self;
              inherit cargoArtifacts;
            };

            treefmtEval = treefmt-nix.lib.evalModule pkgs (
              import ./treefmt.nix { inherit rustToolchain cargoToml; }
            );

            treefmt = treefmtEval.config.build.wrapper;
          in
          f {
            inherit
              pkgs
              rustToolchain
              craneLib
              craneBuildArgs
              cargoArtifacts
              craneArgs
              treefmtEval
              treefmt
              cargoToml
              sharedEnv
              ;
          }
        );
    in
    {
      devShells = forEachSupportedSystem (
        {
          pkgs,
          rustToolchain,
          treefmt,
          craneBuildArgs,
          sharedEnv,
          ...
        }:
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              rustToolchain
              treefmt
            ] ++ craneBuildArgs.nativeBuildInputs;

            buildInputs = craneBuildArgs.buildInputs;

            env = sharedEnv;
          };

          toolchainOnly = pkgs.mkShell {
            nativeBuildInputs = [
              rustToolchain
            ];
          };
        }
      );

      overlays.default = final: prev: {
        krunner-rink = self.packages.${final.system}.default;
      };

      formatter = forEachSupportedSystem ({ treefmt, ... }: treefmt);

      packages = forEachSupportedSystem (
        {
          craneLib,
          craneBuildArgs,
          pkgs,
          cargoToml,
          ...
        }:
        {
          default =
            let
              license = pkgs.lib.licenses.gpl3Only;

              authorSplit = builtins.match "(.+) (:?<(.*)>)" (builtins.head cargoToml.package.authors);

              desktopItem = pkgs.makeDesktopItem {
                name = "plasma-runner-${craneBuildArgs.pname}";
                desktopName = "Rink";
                type = "Service";
                icon = "accessories-calculator";
                comment = cargoToml.package.description;

                extraConfig = {
                  X-KDE-PluginInfo-Author = builtins.head authorSplit;
                  X-KDE-PluginInfo-Email = builtins.elemAt authorSplit 2;
                  X-KDE-PluginInfo-EnabledByDefault = "true";
                  X-KDE-PluginInfo-License = license.spdxId;
                  X-KDE-PluginInfo-Name = craneBuildArgs.pname;
                  X-KDE-PluginInfo-Version = craneBuildArgs.version;
                  X-KDE-ServiceTypes = "Plasma/Runner";
                  X-Plasma-API = "DBus";
                  X-Plasma-DBusRunner-Path = cargoToml.package.metadata.krunner.path;
                  X-Plasma-DBusRunner-Service = cargoToml.package.metadata.krunner.service;
                };
              };
            in
            craneLib.buildPackage (
              craneBuildArgs
              // {
                postInstall = ''
                  mkdir -p $out/share/krunner/dbusplugins
                  cp ${desktopItem}/share/applications/* $out/share/krunner/dbusplugins

                  mkdir -p $out/share/dbus-1/services
                  cat<<EOF > $out/share/dbus-1/services/plasma-runner-${craneBuildArgs.pname}.service
                  [D-BUS Service]
                  Name=${cargoToml.package.metadata.krunner.service}
                  Exec=$out/bin/${craneBuildArgs.pname}
                  EOF
                '';

                meta = {
                  homepage = cargoToml.package.homepage;
                  description = cargoToml.package.description;
                  inherit license;
                };
              }
            );

          docs = craneLib.cargoDoc (
            craneBuildArgs
            // {
              # used to disable `--no-deps`, which crane enables by default,
              # so we include all packages in the resulting docs, to have fully-functional
              # offline docs
              cargoDocExtraArgs = "";
            }
          );
        }
      );

      checks = forEachSupportedSystem (
        {
          craneLib,
          craneBuildArgs,
          treefmtEval,
          ...
        }:
        {
          # can also use `cargoNextest`
          test = craneLib.cargoTest craneBuildArgs;

          doc = craneLib.cargoDoc craneBuildArgs;

          clippy = craneLib.cargoClippy craneBuildArgs;

          treefmt = treefmtEval.config.build.check self;
        }
      );
    };
}
