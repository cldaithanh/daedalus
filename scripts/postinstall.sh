#!/usr/bin/env bash

if [[ "$CI" != "true" ]]; then
  yarn lockfile:fix

  # Let’s patch electron-rebuild to force correct Node.js headers to
  # build native modules against, even in `nix develop`, otherwise, it
  # doesn’t work reliably.
  rootDir=$(dirname "$0")/..
  nix run "${rootDir}#"daedalus.internal.mainnet.rawapp.patchElectronRebuild
fi
