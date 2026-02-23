_: {
  imports = [
    ./homebrew.nix
  ];

  networking.hostName = "goldwater";

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.stateVersion = 6;
}
