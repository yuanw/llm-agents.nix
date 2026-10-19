{
  lib,
  buildGoModule,
  go_1_26,
  fetchFromGitHub,
  git,
  installAgentSkills,
  unpinGoModVersionHook,
  versionCheckHook,
  versionCheckHomeHook,
  mkUpdater,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash vendorHash;
  skills = [
    "open-code-review"
    "open-code-review-delegate"
  ];
in
buildGoModule.override { go = go_1_26; } {
  pname = "open-code-review";
  inherit version vendorHash;

  src = fetchFromGitHub {
    owner = "alibaba";
    repo = "open-code-review";
    tag = "v${version}";
    inherit hash;
  };

  subPackages = [ "cmd/opencodereview" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=v${version}"
    "-X main.GitCommit=nixpkgs"
    "-X main.BuildDate=1970-01-01T00:00:00Z"
  ];

  nativeBuildInputs = [
    installAgentSkills
    # go.mod pins a newer patch release than nixpkgs' go_1_26.
    unpinGoModVersionHook
  ];
  # The source tree also holds SKILL.md files for the VS Code extension and the
  # docs site; install only the top-level skills/ ones.
  dontInstallAgentSkills = true;

  postInstall = ''
    mv $out/bin/opencodereview $out/bin/ocr

    for skill in ${lib.escapeShellArgs skills}; do
      installSkill "$src/skills/$skill"
    done
  '';

  # The cmd tests shell out to git.
  nativeCheckInputs = [ git ];

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
  passthru.updater = mkUpdater {
    kind = "github-source";
    purl = "pkg:github/alibaba/open-code-review";
    depHashKey = "vendorHash";
  };

  meta = with lib; {
    description = "AI-powered code review CLI";
    homepage = "https://github.com/alibaba/open-code-review";
    changelog = "https://github.com/alibaba/open-code-review/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    mainProgram = "ocr";
    maintainers = with maintainers; [ fridh ];
    platforms = platforms.unix;
  };
}
