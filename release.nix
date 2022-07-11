{ system ? builtins.currentSystem
, buildNum ? null # unused
}:

# TODO: ask David Arnold how to idiomatically do hydra jobs with `divnix/std`

let
  flake = (import (
    let lock = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.flake-compat.locked; in fetchTarball {
      url = "https://github.com/${lock.owner}/${lock.repo}/archive/${lock.rev}.tar.gz";
      sha256 = lock.narHash;
    }) { src =  ./.; }).defaultNix;

  inherit (flake) outputs;

  darwin  = outputs.x86_64-darwin.daedalus.packages.x86_64-darwin;
  linux   = outputs.x86_64-linux.daedalus.packages.x86_64-linux;
  windows = outputs.x86_64-linux.daedalus.packages.x86_64-windows;

  inherit (outputs.${system}.daedalus.library) forEachCluster;

in

# XXX: I’m re-defining the pre-flake ones 1:1 for now, but many
# probably don’t make sense anymore and need clean-up. If anything,
# use `${arch}-${os}` everywhere instead of “darwin”/“macos”/“windows”
# etc. – @michalrus

# TODO: add/uncomment `aarch64-darwin` jobs, when we have `aarch64-darwin` in Hydra

forEachCluster (cluster: { daedalus.x86_64-linux = linux.internal.${cluster}.daedalus; }) //

{

  bridgeTable.cardano.x86_64-darwin  = darwin.internal.mainnet.bridgeTable.cardano;
  bridgeTable.cardano.x86_64-linux   = linux.internal.mainnet.bridgeTable.cardano;
  bridgeTable.cardano.x86_64-windows = windows.internal.mainnet.bridgeTable.cardano;

  cardano-node.x86_64-darwin  = darwin.internal.mainnet.cardano-node;
  cardano-node.x86_64-linux   = linux.internal.mainnet.cardano-node;
  cardano-node.x86_64-windows = windows.internal.mainnet.cardano-node;

  # misnomer – @michalrus
  daedalus-installer.x86_64-darwin = darwin.internal.mainnet.daedalus-installer;
  daedalus-installer.x86_64-linux  = linux.internal.mainnet.daedalus-installer;

  shellEnvs.darwin     = outputs.devShells.x86_64-darwin.mainnet;
  #shellEnvs.darwin-arm = outputs.devShells.aarch64-darwin.mainnet;
  shellEnvs.linux      = outputs.devShells.x86_64-linux.mainnet;

  # Only used by (impure) Darwin installer build script
  buildShell.darwin     = outputs.devShells.x86_64-darwin.buildShell;
  #buildShell.darwin-arm = outputs.devShells.aarch64-darwin.buildShell;

  tests = linux.internal.mainnet.tests;

  mono = linux.internal.mainnet.pkgs.mono;
  wine = linux.internal.mainnet.wine;
  wine64 = linux.internal.mainnet.wine64;

  yaml2json.x86_64-darwin = darwin.internal.mainnet.yaml2json;
  yaml2json.x86_64-linux  = linux.internal.mainnet.yaml2json;

  nodejs.x86_64-darwin = darwin.internal.mainnet.nodejs;
  nodejs.x86_64-linux  = linux.internal.mainnet.nodejs;

  # below line blows up hydra with 300 GB derivations on every commit
  # – @michael.bishop <https://github.com/input-output-hk/daedalus/commit/0ce15d03261a4e4a6fa68a1994b4ac8a7d3b3046>
  #installer.x86_64-linux = linux.installer.mainnet;
  #installer.x86_64-windows = windows.installer.mainnet;
  #installer.x86_64-windows = windows.installer.mainnet;

  # TODO: is this really needed? @michalrus
  ifd-pins = let
    inherit (linux.internal.linux.mainnet.pkgs) runCommand lib;
    inputs = { inherit (flake.inputs) iohkNix cardano-wallet cardano-shell; };
  in runCommand "ifd-pins" {} ''
    mkdir $out
    cd $out
    ${lib.concatMapStringsSep "\n" (input: "ln -sv ${input.value} ${input.key}") (lib.attrValues (lib.mapAttrs (key: value: { inherit key value; }) inputs))}
  '';

  recurseForDerivations = {};

}
