{
  description = "A minimal scopes project";
  inputs = {
    scopes.url = "github:Fundament-software/scopes";
    nixpkgs.follows = "scopes/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
    sail-src.url = "github:HappySeaFox/sail";
    sail-src.flake = false;
  };

  outputs = { self, scopes, nixpkgs, flake-utils, nix-filter, sail-src }:
    (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        selfpkgs = self.packages.${system};
        devshell-ldpath =
          pkgs.lib.concatMapStringsSep ":" (lib: "${pkgs.lib.getLib lib}/lib") [
            selfpkgs.sail
            selfpkgs.fgOpenGL
            pkgs.cjson
          ];
        backends = pkgs.llvmPackages_13.stdenv.mkDerivation {
          name = "backends";
          src = nix-filter.lib.filter {
            root = ./.;
            include = [
              "CMakeLists.txt"
              (nix-filter.lib.inDirectory "backendtest")
              (nix-filter.lib.inDirectory "fgOpenGL")
              (nix-filter.lib.inDirectory "fgGLFW")
              (nix-filter.lib.inDirectory "fgOpenGLDesktopBridge")
              (nix-filter.lib.inDirectory "include")
            ];
          };

          nativeBuildInputs = [ pkgs.cmake ];
          buildInputs = [ pkgs.libglvnd pkgs.glfw pkgs.xorg.libX11 pkgs.xorg.libXrandr ];
          outputs = [ "out" ];

          cmakeFlags = [ "-DUSE_DEFAULT_FOLDERS=1" ];

          # installPhase = ''
          #   mkdir -p $out/build-dump
          #   cp -r . $out/build-dump
          # '';
        };
      in {
        packages = {
          fgOpenGL = backends;
          sail = pkgs.stdenv.mkDerivation {
            name = "sail";
            src = sail-src;

            cmakeFlags = [ "-DSAIL_COMBINE_CODECS=ON" ];
            buildInputs =
              [ pkgs.cmake pkgs.libpng pkgs.libjpeg_turbo pkgs.libwebp ];
            postInstall = ''
              # This shouldn't be needed as sail generates correct pkg-config files
              # but scopes doesn't use it and we were relying on nix magically putting
              # the include in as an '-isystem' include.
              # the nixpkgs default adds /include regardless of what the pkg-config files request
              # so we manually add the correct path
              mkdir "$out/nix-support" || true
              cat <<- EOD > $out/nix-support/setup-hook
                export NIX_CFLAGS_COMPILE="\''${NIX_CFLAGS_COMPILE:-} -isystem $out/include/sail"
              EOD
            '';
          };
        };
        devShell = pkgs.mkShell {
          buildInputs = [
            scopes.packages.${system}.scopes
            backends
            pkgs.cjson
            selfpkgs.sail
          ];

          shellHook = ''
            export LD_LIBRARY_PATH=${devshell-ldpath}:$LD_LIBRARY_PATH
          '';
        };
      })) // {

      };

}
