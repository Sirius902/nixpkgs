{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  buildPackages,
  installShellFiles,
  versionCheckHook,
  nix-update-script,
}:

buildGoModule (finalAttrs: {
  pname = "mrpack-install";
  version = "0.23.0";

  src = fetchFromGitHub {
    owner = "nothub";
    repo = "mrpack-install";
    tag = "v${finalAttrs.version}";
    hash = "sha256-VoGUWN1AZRXGl/4MjoC0vNN2saWuOCS++Wl2M4zda+w=";
  };

  vendorHash = "sha256-cmVqOA1rKa7guwW0GEM4TLpreOVh8p7vI/z8SIsxtdI=";

  # Resolving the latest Minecraft version requires network and breaks
  # installPhase. Move it to `server`, the only command that needs it.
  postPatch = ''
    substituteInPlace cmd/server.go \
      --replace-fail 'cobra.OnInitialize(func() {' \
        'serverCmd.PreRun = (func(*cobra.Command, []string) {'
  '';

  excludedPackages = [
    "e2e"
    "tools"
  ];

  ldflags = [
    "-s"
    "-X github.com/nothub/mrpack-install/internal/buildinfo.version=${finalAttrs.version}"
    "-X github.com/nothub/mrpack-install/internal/buildinfo.commit=${finalAttrs.src.rev}"
    "-X github.com/nothub/mrpack-install/internal/buildinfo.date=1970-01-01T00:00:00Z"
    "-X github.com/nothub/mrpack-install/internal/buildinfo.tool=nixpkgs"
  ];

  # tests serve fixtures from local httptest servers
  __darwinAllowLocalNetworking = true;

  checkFlags = lib.optionals stdenv.hostPlatform.isDarwin [
    # sendfile(2) does not work with __darwinAllowLocalNetworking, see NixOS/nix#16632
    "-skip=^TestFetchMetadata$"
  ];

  nativeBuildInputs = [
    installShellFiles
  ];

  postInstall =
    let
      mrpack-install = "${stdenv.hostPlatform.emulator buildPackages} $out/bin/mrpack-install";
    in
    lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) ''
      installShellCompletion --cmd mrpack-install \
        --bash <(${mrpack-install} completion bash) \
        --fish <(${mrpack-install} completion fish) \
        --zsh <(${mrpack-install} completion zsh)
    '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "CLI application for installing Minecraft servers and Modrinth modpacks";
    homepage = "https://github.com/nothub/mrpack-install";
    changelog = "https://github.com/nothub/mrpack-install/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ encode42 ];
    mainProgram = "mrpack-install";
  };
})
