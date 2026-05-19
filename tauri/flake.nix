{
  description = "A Nix-flake-based Tauri development environment";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                inputs.self.overlays.default
              ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        rustToolchain =
          with inputs.fenix.packages.${prev.stdenv.hostPlatform.system};
          combine (
            with stable;
            [
              clippy
              rustc
              cargo
              rustfmt
              rust-src
            ]
          );
      };

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        let
          morsmortium-gtk-nocsd = pkgs.stdenv.mkDerivation {
            pname = "morsmortium-gtk-nocsd";
            version = "0-unstable-2026-05-19";

            src = pkgs.fetchgit {
              url = "https://codeberg.org/MorsMortium/GTK-NoCSD.git";
              rev = "b9b6ddacf53d2d4253697472384b31ec09c60495";
              sha256 = "sha256-3aHhGjlcLus5TaOaniJVe4qs+y56Z6UJj6NjTdAv+x4=";
            };

            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = with pkgs; [
              libadwaita
              glib
            ];

            buildPhase = ''
              make build
            '';

            installPhase = ''
              mkdir -p $out/lib
              cp libgtk-nocsd.so.0 $out/lib/
            '';
          };

        in
        {
          default = pkgs.mkShell rec {
            packages = with pkgs; [
              rustToolchain
              openssl
              pkg-config
              cargo-deny
              cargo-edit
              cargo-watch
              rust-analyzer
              self.formatter.${system}
            ];

            nativeBuildInputs = with pkgs; [
              cargo-tauri
              nodejs
              pnpm
            ];

            buildInputs = with pkgs; [
              librsvg
              webkitgtk_4_1
              glib
              gtk3
              gdk-pixbuf
              cairo
              dbus
              libsoup_3
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-plugins-bad
              gst_all_1.gst-plugins-ugly
            ];

            env = {
              # Required by rust-analyzer
              RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
            };

            shellHook = ''
              export XDG_DATA_DIRS="$GSETTINGS_SCHEMAS_PATH:$XDG_DATA_DIRS"
              export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath buildInputs}:$LD_LIBRARY_PATH"
              export LD_PRELOAD="${morsmortium-gtk-nocsd}/lib/libgtk-nocsd.so.0:$LD_PRELOAD"
            '';
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}
