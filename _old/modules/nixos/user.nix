{ inputs, ... }:
let
  inherit (inputs.self.commonModules) me;
in
{
  users.users.${me.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "trusted"
    ];
  };

  # No mutable users
  users.mutableUsers = true;
}
