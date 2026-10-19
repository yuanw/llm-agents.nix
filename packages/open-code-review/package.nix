{
  lib,
  stdenv,
  fetchFromGitHub,
  installAgentSkills,
  platformSource,
  versionCheckHook,
  versionCheckHomeHook,
  mkUpdater,
}:

let
  source = platformSource {
    hashesFile = ./hashes.json;
    platforms = {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
      aarch64-darwin = "darwin-arm64";
    };
    urlTemplate = "https://github.com/alibaba/open-code-review/releases/download/v{version}/opencodereview-{platform}";
  };
  inherit (source) version;

  # The releases ship only the binary, so the skills come from the source tree.
  # The "platform" updater rewrites hashes.json only, so this hash must be
  # refreshed by hand on a version bump (the build fails loudly otherwise).
  skillsSrc = fetchFromGitHub {
    owner = "alibaba";
    repo = "open-code-review";
    tag = "v${version}";
    hash = "sha256-qRUlkbhGSPv+nxV4yig7EiQ6tNVyGMivm30qZd+TQwc=";
  };
  skills = [
    "open-code-review"
    "open-code-review-delegate"
  ];
in
stdenv.mkDerivation {
  pname = "open-code-review";
  inherit (source) version src;

  # Upstream releases are single statically linked Go binaries.
  dontUnpack = true;

  nativeBuildInputs = [ installAgentSkills ];
  dontInstallAgentSkills = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 $src $out/bin/ocr
    runHook postInstall
  '';

  postInstall = ''
    for skill in ${lib.escapeShellArgs skills}; do
      installSkill "${skillsSrc}/skills/$skill"
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];
  versionCheckProgramArg = [ "version" ];

  postInstallCheck = ''
    for skill in ${lib.escapeShellArgs skills}; do
      test -f "$out/share/skills/open-code-review/$skill/SKILL.md"
    done
  '';

  passthru.category = "Code Review";
  passthru.updater = mkUpdater (
    source.updater
    // {
      versionSource = {
        type = "github";
        owner = "alibaba";
        repo = "open-code-review";
      };
    }
  );

  meta = with lib; {
    description = "AI-powered code review CLI";
    homepage = "https://github.com/alibaba/open-code-review";
    changelog = "https://github.com/alibaba/open-code-review/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "ocr";
    maintainers = with maintainers; [ fridh ];
    platforms = source.platforms;
  };
}
