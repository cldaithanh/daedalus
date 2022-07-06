{ inputs, cell }:

{
  mkInternal = cluster: import ./old-code/old-default.nix {
    inherit inputs;
    cluster = cluster;
    buildNum = toString cell.library.buildNumber;
    target = "x86_64-darwin";
    buildSystem = inputs.nixpkgs.system;
  };
}
