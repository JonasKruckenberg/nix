{ inputs, pkgs, ... }:
let
  inherit (inputs.self.commonModules) me;
in
{
  users.knownUsers = [ me.username ];
  users.users.${me.username} = {
    shell = pkgs.zsh;
    uid = 1001;
  };
  system.primaryUser = me.username;

  #  users.knownUsers = map (user: user.username) inputs.self.commonModules.users;
  #
  #  users.users = lib.mapAttrs (name: _: {
  #    home = "/Users" + "/${name}";
  #  }) inputs.self.commonModules.users;
  #
  #  system.primaryUser = "jonaskruckenberg";
}
