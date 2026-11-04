{
  lib,
  stdenvNoCC,
  bash,
}:
stdenvNoCC.mkDerivation {
  pname = "dux-audigon";
  inherit ((lib.importJSON ../plugin/plugin.json)) version;

  src = ../plugin;

  # patchShebangs points the helper at this bash
  buildInputs = [bash];

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';
}
