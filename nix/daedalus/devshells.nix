{ inputs, cell }:

let

  # Infinite recursion in evaluation of `devShells.default`, if we use `cell.library.forEachCluster`.
  # TODO: submit issue to `divnix/std`
  inherit (import (inputs.self + "/nix/daedalus/library/clusters.nix")) forEachCluster;
  #inherit (cell.library) forEachCluster;

  system = inputs.nixpkgs.system;

in

if system == "x86_64-linux" || system == "x86_64-darwin" || system == "aarch64-darwin" then

  # E.g. `nix develop .#testnet`:
  (forEachCluster (cluster:
    import ./library/old-code/old-shell.nix {
      inherit inputs system cluster;
      pkgs = inputs.nixpkgs;
      daedalusPkgs = cell.library.${system}.mkInternal cluster;
    }
  ))

  // rec {

    # Plain `nix develop`:
    default = cell.devshells.mainnet;

    # E.g. `nix develop .#fixYarnLock` – TODO: shouldn’t it be a `nix run` script instead?
    inherit (default) fixYarnLock buildShell devops;

  }

else abort "unsupported system: ${inputs.nixpkgs.system}"
