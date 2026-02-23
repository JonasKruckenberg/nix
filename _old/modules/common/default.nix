{ flake, ... }:
{
  me = import ./me.nix;

  default = {
    # Necessary for using flakes on this system.
    nix.settings.experimental-features = "nix-command flakes";
    nix.channel.enable = false;

    system.configurationRevision = flake.rev or flake.dirtyRev or null;
  };
}
