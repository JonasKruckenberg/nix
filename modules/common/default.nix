_: {
  nix.settings.experimental-features = "nix-command flakes";
  nix.channel.enable = false;

  nixpkgs.config.allowUnfree = true;

  nix.gc.automatic = true;
}
