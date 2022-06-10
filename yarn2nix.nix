{ lib, yarn, nodejs, python3, python2, api, apiVersion, cluster, buildNum, nukeReferences, fetchzip, daedalus, stdenv, win64 ? false, wine64, runCommand, fetchurl, unzip, spacedName, iconPath, launcherConfig, pkgs, python27
, libcap
, libgcrypt
, libgpgerror
, libidn2
, libunistring
, libusb
, libusb1
, libudev
, lz4
, pkgconfig
, systemd
, writeShellScript
, xz
, nodePackages
, zlib
, strace }:
let
  cluster' = launcherConfig.networkName;
  yarn2nix = import (fetchzip {
    url = "https://github.com/moretea/yarn2nix/archive/v1.0.0.tar.gz";
    sha256 = "02bzr9j83i1064r1r34cn74z7ccb84qb5iaivwdplaykyyydl1k8";
  }) {
    inherit pkgs nodejs yarn;
  };
  dotGitExists = builtins.pathExists ./.git;
  isNix2 = 0 <= builtins.compareVersions builtins.nixVersion "1.12";
  canUseFetchGit = dotGitExists && isNix2;
  origPackage = builtins.fromJSON (builtins.readFile ./package.json);
  newPackage = (origPackage // {
    productName = spacedName;
  }) // lib.optionalAttrs (win64 == false) {
    main = "main/index.js";
  };
  newPackagePath = builtins.toFile "package.json" (builtins.toJSON newPackage);
  electronVersion = origPackage.dependencies.electron;
  electronPath = "https://github.com/electron/electron/releases/download/v${electronVersion}";
  windowsElectron = fetchurl {
    url = "${electronPath}/electron-v${electronVersion}-win32-x64.zip";
    sha256 = "0gcshwmx0cy8146pcr0mavwl3rv86ma59ar6v4rgl5pl6pgmfifc";
  };
  electronPathHash = builtins.hashString "sha256" electronPath;
  electron-cache = runCommand "electron-cache" {} ''
    # newer style
    mkdir -p $out/${electronPathHash}/
    ln -sv ${windowsElectron} $out/${electronPathHash}/electron-v${electronVersion}-win32-x64.zip
    mkdir $out/httpsgithub.comelectronelectronreleasesdownloadv${electronVersion}electron-v${electronVersion}-win32-x64.zip
    ln -s ${windowsElectron} $out/httpsgithub.comelectronelectronreleasesdownloadv${electronVersion}electron-v${electronVersion}-win32-x64.zip/electron-v${electronVersion}-win32-x64.zip
  '';
  electron-node-headers = fetchurl {
    url = "https://www.electronjs.org/headers/v${electronVersion}/node-v${electronVersion}-headers.tar.gz";
    sha256 = "1qkzqv0k7hxc0kzbri69caabhwzwccl415kg41iksryawsbmciiq";
  };
  electron-node-headers-unpacked = runCommand "electron-node-headers-${electronVersion}-unpacked" {} ''
    tar -xf ${electron-node-headers}
    mkdir -p $out
    mv node_headers/* $out/
  '';
  filter = name: type: let
    baseName = baseNameOf (toString name);
    sansPrefix = lib.removePrefix (toString ./.) name;
  in (
      baseName == "package.json" ||
      baseName == "gulpfile.js" ||
      (lib.hasPrefix "/source" sansPrefix) ||
      baseName == ".babelrc" ||
      sansPrefix == "/scripts" ||
      sansPrefix == "/scripts/package.js" ||
      sansPrefix == "/installers" ||
      (lib.hasPrefix "/installers/icons" sansPrefix)
      );
  commonInputs = [
    python27
    python3
    nukeReferences
    strace
    pkgconfig
    libusb
  ];

  # We patch `node_modules/electron-rebuild` to force specific Node.js
  # headers to be used when building native extensions for
  # Electron. Electron’s Node.js ABI differs from the same version of
  # Node.js, because different libraries are used in Electon,
  # e.g. BoringSSL instead of OpenSSL,
  # cf. <https://www.electronjs.org/docs/latest/tutorial/using-native-node-modules>
  #
  # We also use this same code in `shell.nix`, since for some reason
  # `electron-rebuild` there determines incorrect headers to use
  # automatically, and we keep getting ABI errors. TODO: investigate
  # why…
  #
  # TODO: That `sed` is rather awful… Can it be done better? – @michalrus
  patchElectronRebuild = writeShellScript "patch-electron-rebuild" ''
    echo 'Patching electron-rebuild to force our Node.js headers…'

    nodeGypJs=lib/src/module-type/node-gyp.js
    if [ ! -e $nodeGypJs ] ; then
      # makes it work both here, and in shell.nix:
      nodeGypJs="node_modules/electron-rebuild/$nodeGypJs"
    fi
    if [ ! -e $nodeGypJs ] ; then
      echo >&2 'fatal: shouldn’t happen unless electron-rebuild changes'
      exit 1
    fi

    # Patch idempotently (matters in repetitive shell.nix):
    if ! grep -qF ${electron-node-headers} $nodeGypJs ; then
      sed -r 's|const extraNodeGypArgs.*|\0 extraNodeGypArgs.push("--tarball", "${electron-node-headers}", "--nodedir", "${electron-node-headers-unpacked}");|' -i $nodeGypJs
    fi
  '';
in
yarn2nix.mkYarnPackage {
  name = "daedalus-js";
  src = lib.cleanSourceWith { inherit filter; src = ./.; name = "daedalus"; };
  API = api;
  API_VERSION = apiVersion;
  CI = "nix";
  NETWORK = cluster';
  BUILD_NUMBER = "${toString buildNum}";
  NODE_ENV = "production";
  BUILDTYPE = "Release";
  extraBuildInputs = commonInputs ++ (if win64 then [ unzip wine64 ] else []);
  installPhase = let
    nukeAllRefs = ''
      # the webpack utils embed the original source paths into map files, so backtraces from the 1 massive index.js can be converted back to multiple files
      # but that causes the derivation to depend on the original inputs at the nix layer, and double the size of the linux installs
      # nuke-refs will just replace all storepaths with an invalid one
      for x in {main,renderer}/{0.,}index.js{,.map} main/preload.js{,.map} main/0.js{,.map} renderer/styles.css.map; do
        nuke-refs $x
      done
    '';
  in if win64 then ''
    # old style
    export ELECTRON_CACHE=${electron-cache}
    # new style
    mkdir -pv home/.cache/
    export HOME=$(realpath home)
    ln -sv ${electron-cache} $HOME/.cache/electron

    cp ${newPackagePath} package.json
    mkdir -p installers/icons/${cluster}/${cluster}
    cp ${iconPath.base}/* installers/icons/${cluster}/${cluster}/
    yarn --offline package --win64 --icon installers/icons/${cluster}/${cluster}
    ls -ltrh release/win32-x64/Daedalus*-win32-x64/
    cp -r release/win32-x64/Daedalus*-win32-x64 $out
    pushd $out/resources/app/dist
    ${nukeAllRefs}
    popd
    rm -rf $out/resources/app/{installers,launcher-config.yaml,gulpfile.js,home}

    mkdir -pv $out/resources/app/node_modules
    cp -r $node_modules/{\@babel,\@protobufjs,regenerator-runtime,node-fetch,\@trezor,runtypes,parse-uri,randombytes,safe-buffer,bip66,pushdata-bitcoin,bitcoin-ops,typeforce,varuint-bitcoin,create-hash,blake2b,nanoassert,blake2b-wasm,bs58check,bs58,base-x,create-hmac,wif,ms,semver-compare,long,define-properties,object-keys,has,function-bind,es-abstract,has-symbols,json-stable-stringify,cashaddrjs,big-integer,inherits,bchaddrjs,cross-fetch,trezor-connect,js-chain-libs-node,bignumber.js,call-bind,get-intrinsic,base64-js,ieee754,util-deprecate,bech32,blake-hash,blake2,tiny-secp256k1,bn.js,elliptic,minimalistic-assert,minimalistic-crypto-utils,brorand,hash.js,hmac-drbg,int64-buffer,object.values,bytebuffer,protobufjs,usb-detection,socks,socks-proxy-agent,ip,smart-buffer,ripple-lib,lodash,jsonschema,ripple-address-codec,ripple-keypairs,ripple-lib-transactionparser,ripple-binary-codec,buffer,decimal.js} $out/resources/app/node_modules

    cd $out/resources/app/
    unzip ${./nix/windows-usb-libs.zip}
  '' else ''
    mkdir -pv home/.cache/
    export HOME=$(realpath home)
    yarn --offline run build

    #export DEBUG=electron-rebuild

    ls -ltrha $NIX_BUILD_TOP/daedalus/node_modules/
    function dup() {
      cp -vr node_modules/''${1}/ node_modules/''${1}-temp
      rm -v node_modules/''${1}
      mv -v node_modules/''${1}-temp node_modules/''${1}
      chmod -R +w node_modules/''${1}
    }

    dup node-hid
    dup usb
    dup @ledgerhq
    dup electron-chromedriver
    dup blake-hash
    dup blake2
    dup tiny-secp256k1
    dup usb-detection

    # We ship debug version because the release one has issues with ledger nano s
    node_modules/.bin/electron-rebuild -w usb --useCache -s --debug

    mkdir -p $out/bin $out/share/daedalus
    cp -R dist/* $out/share/daedalus
    cp ${newPackagePath} $out/share/daedalus/package.json
    pushd $out/share/daedalus
    ${nukeAllRefs}
    popd
    mkdir -p $out/share/fonts
    ln -sv $out/share/daedalus/renderer/assets $out/share/fonts/daedalus
    mkdir -pv $out/share/daedalus/node_modules
    cp -r $node_modules/{\@babel,\@protobufjs,regenerator-runtime,node-fetch,\@trezor,runtypes,parse-uri,randombytes,safe-buffer,bip66,pushdata-bitcoin,bitcoin-ops,typeforce,varuint-bitcoin,create-hash,blake2b,nanoassert,blake2b-wasm,bs58check,bs58,base-x,create-hmac,wif,ms,semver-compare,long,define-properties,object-keys,has,function-bind,es-abstract,has-symbols,json-stable-stringify,cashaddrjs,big-integer,inherits,bchaddrjs,cross-fetch,trezor-connect,js-chain-libs-node,bignumber.js,call-bind,get-intrinsic,base64-js,ieee754,util-deprecate,bech32,blake-hash,blake2,tiny-secp256k1,bn.js,elliptic,minimalistic-assert,minimalistic-crypto-utils,brorand,hash.js,hmac-drbg,int64-buffer,object.values,bytebuffer,protobufjs,usb-detection,socks,socks-proxy-agent,ip,smart-buffer,ripple-lib,lodash,jsonschema,ripple-address-codec,ripple-keypairs,ripple-lib-transactionparser,ripple-binary-codec,buffer,decimal.js} $out/share/daedalus/node_modules/
    find $out $NIX_BUILD_TOP -name '*.node'

    mkdir -pv $out/share/daedalus/build
    cp node_modules/usb/build/Debug/usb_bindings.node $out/share/daedalus/build/usb_bindings.node
    cp node_modules/node-hid/build/Debug/HID_hidraw.node $out/share/daedalus/build/HID_hidraw.node
    for file in $out/share/daedalus/build/usb_bindings.node $out/share/daedalus/build/HID_hidraw.node; do
      $STRIP $file
      patchelf --shrink-rpath $file
    done

    node_modules/.bin/electron-rebuild -w usb-detection --useCache -s
    cp node_modules/usb-detection/build/Release/detection.node $out/share/daedalus/build/detection.node
    for file in $out/share/daedalus/build/detection.node; do
      $STRIP $file
      patchelf --shrink-rpath $file
    done
  '';
  #allowedReferences = [ "out" ];
  #allowedRequisites = [
  #  systemd.lib
  #  stdenv.cc.cc.lib
  #  stdenv.cc.cc
  #  stdenv.cc.libc
  #  stdenv.cc.libc.bin
  #  stdenv.cc.libc.dev
  #  libcap.lib
  #  lz4
  #  zlib
  #  xz.out
  #  libgcrypt
  #  libidn2.out
  #  libgpgerror
  #  libunistring
  #  libusb1
  #] ++ stdenv.cc.libc.buildInputs;

  # `yarnPreBuild` is only used in `yarn2nix.mkYarnModules`, not `yarn2nix.mkYarnPackage`:
  yarnPreBuild = ''
    mkdir -p $HOME/.node-gyp/${nodejs.version}
    echo 9 > $HOME/.node-gyp/${nodejs.version}/installVersion
    ln -sfv ${nodejs}/include $HOME/.node-gyp/${nodejs.version}
  '';

  inherit patchElectronRebuild; # for use in shell.nix

  pkgConfig = {
    electron-rebuild = {
      postInstall = ''
        ${patchElectronRebuild}
      '';
    };
  };

  # work around some purity problems in nix
  yarnLock = ./yarn.lock;
  packageJSON = ./package.json;
}
