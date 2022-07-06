{ inputs, cell }:

let
  inherit (cell.library) forEachCluster;
  export = internal: attrName: builtins.mapAttrs (k: v: v.${attrName}) internal;
in

if inputs.nixpkgs.system == "x86_64-linux" then rec {

  # E.g. `nix build -L .#daedalus.installer.testnet`
  default = x86_64-linux;

  x86_64-linux = rec {
    internal  = forEachCluster cell.library.x86_64-linux.mkInternal;
    installer = export internal "wrappedBundle";
    package   = export internal "daedalus";
  };

  # E.g. `nix build -L .#daedalus-x86_64-windows.installer.testnet`
  x86_64-windows = rec {
    internal  = forEachCluster cell.library.x86_64-windows.mkInternal;
    installer = export internal "windows-installer";
  };

} else if inputs.nixpkgs.system == "x86_64-darwin" then rec {

  # E.g. `nix build -L .#daedalus.installer.testnet`
  default = x86_64-darwin;

  x86_64-darwin = rec {
    internal  = forEachCluster cell.library.x86_64-darwin.mkInternal;
    installer = package;
    package   = forEachCluster (_: abort "Darwin package/installer is not yet a pure build, please use ‘scripts/build-installer-unix.sh’.");
  };

} else if inputs.nixpkgs.system == "aarch64-darwin" then rec {

  # E.g. `nix build -L .#daedalus.installer.testnet`
  default = aarch64-darwin;

  aarch64-darwin = rec {
    internal  = forEachCluster cell.library.x86_64-darwin.mkInternal;
    installer = package;
    package   = forEachCluster (_: abort "Darwin package/installer is not yet a pure build, please use ‘scripts/build-installer-unix.sh’.");
  };

  # TODO: clean up

  # TODO: allow building `x86_64-darwin` on `aarch64-darwin`?

} else abort "unsupported system: ${inputs.nixpkgs.system}"
