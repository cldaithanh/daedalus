{ inputs
, system
}:

let

  pkgs = import inputs.nixpkgs-src {
    inherit system;
    inherit (inputs.haskellNix) config;
    overlays = [
      inputs.haskellNix.overlay
      inputs.iohkNix.overlays.cardano-lib
    ];
  };

  # TODO: can we use the filter in iohk-nix instead?
  # TODO: or <https://github.com/hercules-ci/gitignore.nix>? – @michalrus
  cleanSourceFilter = with pkgs.stdenv;
    name: type: let baseName = baseNameOf (toString name); in ! (
      # Filter out .git repo
      (type == "directory" && baseName == ".git") ||
      # Filter out editor backup / swap files.
      lib.hasSuffix "~" baseName ||
      builtins.match "^\\.sw[a-z]$" baseName != null ||
      builtins.match "^\\..*\\.sw[a-z]$" baseName != null ||

      # Filter out locally generated/downloaded things.
      baseName == "dist" ||
      baseName == "node_modules" ||

      # Filter out the files which I'm editing often.
      lib.hasSuffix ".nix" baseName ||
      lib.hasSuffix ".dhall" baseName ||
      lib.hasSuffix ".hs" baseName ||
      # Filter out nix-build result symlinks
      (type == "symlink" && lib.hasPrefix "result" baseName)
    );

  lib = pkgs.lib;
in
#lib //
{ # FIXME: is `lib //` really a good idea here…? – @michalrus
  inherit pkgs cleanSourceFilter;
}
