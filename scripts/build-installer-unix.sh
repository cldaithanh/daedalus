#!/usr/bin/env bash
set -e
source "$(dirname "$0")/utils.sh"

# DEPENDENCIES (binaries should be in PATH):
#   0. 'git'
#   1. 'curl'
#   2. 'nix'

rootDir=$(dirname "$0")/..
CLUSTERS="$(xargs echo -n < "${rootDir}/installer-clusters.cfg")"

###
### Argument processing
###
fast_impure=
verbose=
build_id=0
test_installer=
code_signing_config=
signing_config=

case "$(uname -s)" in
        Darwin ) export OS_NAME=darwin; export os=osx;   export key=macos-3.p12;;
        Linux )  export OS_NAME=linux;  export os=linux; export key=linux.p12;;
        * )     usage "Unsupported OS: $(uname -s)";;
esac

set -u ## Undefined variable firewall enabled
while test $# -ge 1
do case "$1" in
           --clusters )                                     CLUSTERS="$2"; shift;;
           --fast-impure )                               export fast_impure=true;;
           --build-id )       validate_arguments "build identifier" "$2"; build_id="$2"; shift;;
           --nix-path )       validate_arguments "NIX_PATH value" "$2";
                                                     export NIX_PATH="$2"; shift;;
           --test-installer )                         test_installer="--test-installer";;

           ###
           --verbose )        echo "$0: --verbose passed, enabling verbose operation"
                                                             verbose=t;;
           --quiet )          echo "$0: --quiet passed, disabling verbose operation"
                                                             verbose=;;
           --help )           usage;;
           "--"* )            usage "unknown option: '$1'";;
           * )                break;; esac
   shift; done

set -e
echo "${verbose}"
if test -n "${verbose}"
then set -x
fi

# We have to pass it somehow to the flake…
if [ -n "$build_id" ] && [ "$build_id" != 0 ] ; then
  echo "$build_id" > .build-number
  if [ -n "${BUILDKITE_JOB_ID:-}" ]; then # if in real Buildkite,
    git update-index --assume-unchanged .build-number # lie to Nix that the repo was unchanged, more impurity…
  fi
fi

if [ -f /var/lib/buildkite-agent/code-signing-config.json ]; then
  code_signing_config="--code-signing-config /var/lib/buildkite-agent/code-signing-config.json"
fi

if [ -f /var/lib/buildkite-agent/signing-config.json ]; then
  signing_config="--signing-config /var/lib/buildkite-agent/signing-config.json"
fi

export daedalus_version="${1:-dev}"

mkdir -p ~/.local/bin

if test -e "dist" -o -e "release" -o -e "node_modules"
then rm -rf dist release node_modules || true
fi

export PATH=$HOME/.local/bin:$PATH
if [ -n "${NIX_SSL_CERT_FILE-}" ]; then export SSL_CERT_FILE=$NIX_SSL_CERT_FILE; fi

upload_artifacts() {
    retry 5 buildkite-agent artifact upload "$@" --job "$BUILDKITE_JOB_ID"
}

upload_artifacts_public() {
    retry 5 buildkite-agent artifact upload "$@" "${ARTIFACT_BUCKET:-}" --job "$BUILDKITE_JOB_ID"
}

function checkItnCluster() {
  for c in $2
  do
    if [[ "${c}" == "${1}" ]]
    then
      echo 1
    fi
  done
}

# Build/get cardano bridge which is used by make-installer
echo '~~~ Prebuilding cardano bridge'
nix build -L --no-link "${rootDir}#"daedalus.internal.mainnet.daedalus-bridge

pushd installers
    echo '~~~ Prebuilding dependencies for cardano-installer, quietly..'
    nix build -L --no-link "${rootDir}#"daedalus.internal.mainnet.daedalus-installer
    echo '~~~ Building the cardano installer generator..'

    for cluster in ${CLUSTERS}
    do
          echo "~~~ Generating installer for cluster ${cluster}.."

          export DAEDALUS_CLUSTER="${cluster}"
          APP_NAME="csl-daedalus"
          rm -rf "${APP_NAME}"

          echo "Cluster type: cardano"
          CARDANO_BRIDGE=$(
            json=$(nix build --no-link --json "${rootDir}#daedalus.internal.${cluster}.daedalus-bridge") ;
            echo "$json" | nix run "${rootDir}#"daedalus.internal.mainnet.pkgs.jq -- -r '.[0].outputs.out'
          )
          BRIDGE_FLAG="--cardano ${CARDANO_BRIDGE}"

          INSTALLER_CMD=("make-installer"
                         "${test_installer}"
                         "${code_signing_config}"
                         "${signing_config}"
                         "${BRIDGE_FLAG}"
                         "  --build-job        ${build_id}"
                         "  --cluster          ${cluster}"
                         "  --out-dir          ${APP_NAME}")

          nix build -o cfg-files -L "${rootDir}#daedalus.internal.${cluster}.launcherConfigs.configFiles"
          cp -v cfg-files/* .
          chmod -R +w .
          echo 'Running make-installer in Nix shell'
          nix develop "${rootDir}#"buildShell --command sh -c "${INSTALLER_CMD[*]}"

          if [ -d ${APP_NAME} ]; then
                  if [ -n "${BUILDKITE_JOB_ID:-}" ]
                  then
                          echo "Uploading the installer package.."
                          export PATH=${BUILDKITE_BIN_PATH:-}:$PATH
                          if [ -n "${UPLOAD_DIR_OVERRIDE:-}" ] ; then
                            upload_dir="$UPLOAD_DIR_OVERRIDE"
                            mv "$APP_NAME" "$upload_dir"
                          else
                            upload_dir="$APP_NAME"
                          fi
                          upload_artifacts_public "${upload_dir}/*"
                          mv "launcher-config.yaml" "launcher-config-${cluster}.macos64.yaml"
                          upload_artifacts "launcher-config-${cluster}.macos64.yaml"
                          rm -rf "$upload_dir"
                  fi
          else
                  echo "Installer was not made."
          fi
    done
popd || exit 1

exit 0
