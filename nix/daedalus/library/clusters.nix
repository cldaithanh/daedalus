rec {

  allClusters =
    let unique = builtins.foldl' (acc: e: if builtins.elem e acc then acc else acc ++ [ e ]) []; in
    unique (
      builtins.map builtins.unsafeDiscardStringContext (
        builtins.filter (el: builtins.isString el && el != "") (
          builtins.split "[ \n\r\t]+" (
            builtins.readFile ../../../installer-clusters.cfg
            + "\n" +
            builtins.readFile ../../../installer-clusters-available.cfg
          ))));

  forEachCluster = fun: builtins.listToAttrs
    (builtins.map (cluster: { name = cluster; value = fun cluster; }) allClusters);

}
