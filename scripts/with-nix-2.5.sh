#!/usr/bin/env bash
set -e

if [ $# -eq 0 ] ; then
  echo >&2 "fatal: usage: $0 <command> [<args>...]"
  exit 1
fi

echo "~~~ Obtaining ‘pkgs.nixUnstable’"

# *Maybe* prevent segfaults on `aarch64-darwin` in `GC_*` code:
export GC_DONT_GC=1 # <https://chromium.googlesource.com/chromiumos/third_party/gcc/+/f4131b9cddd80547d860a6424ee1644167a330d6/gcc/gcc-4.6.0/boehm-gc/doc/README.environment#151>

export NIX_CONFIG='
  experimental-features = nix-command flakes
'

# TODO: this is rather awful – make a `nix run` script instead? So `nix run .#withNixUnstable -- ./scripts/build…`
rootDir=$(dirname "$0")/..
nixUnstable=$(json=$(nix build --no-link --json "${rootDir}#"daedalus.internal.mainnet.pkgs.nixUnstable) ;
              echo "$json" | nix run "${rootDir}#"daedalus.internal.mainnet.pkgs.jq -- -r '.[0].outputs.out')

PATH="$nixUnstable/bin:$PATH"

nix --version
echo

echo "~~~ Running ‘$1’"

exec "$@"
