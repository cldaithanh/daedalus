{ inputs, cell }:

rec {

  aarch64-darwin = import ./library/aarch64-darwin.nix { inherit inputs cell; };
  x86_64-darwin  = import ./library/x86_64-darwin.nix  { inherit inputs cell; };
  x86_64-linux   = import ./library/x86_64-linux.nix   { inherit inputs cell; };
  x86_64-windows = import ./library/x86_64-windows.nix { inherit inputs cell; };

  # Infinite recursion in evaluation of `devShells.default`, when we don’t break here.
  # TODO: submit issue to `divnix/std`
  inherit (import (inputs.self + "/nix/daedalus/library/clusters.nix")) forEachCluster allClusters;

  # Nix flakes don’t allow passing arguments, which is good, but our
  # apps need to be able to display CI build numbers to end users (for
  # easier investigation), so we make CI write this information to a
  # file (slightly impure):
  buildNumber =
      let
        default = 0;
        file = "/.build-number";
        path = inputs.self + file;
      in
      if builtins.pathExists path then
        let contents = builtins.replaceStrings ["\n" "\r" "\t" " "] ["" "" "" ""] (builtins.readFile path); in
        if contents == "" then builtins.trace "‘${file}’ is empty, using ${toString default}" default
        else  if builtins.length (builtins.split "[^0-9]" contents) == 1 then builtins.fromJSON contents
        else abort "‘${file}’ doesn’t contain an integer"
      else builtins.trace "‘${file}’ not found, using ${toString default}" default
      ;

}
