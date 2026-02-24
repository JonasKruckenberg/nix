_: {
  users.users.jonaskruckenberg = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "trusted"
    ];

  };

  users.mutableUsers = true;

  nix.gc = {
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
