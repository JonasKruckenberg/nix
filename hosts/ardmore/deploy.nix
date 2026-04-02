{ pkgs, ... }:
{
  # Dedicated CI deploy user.
  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    shell = pkgs.zsh;
  };
  users.groups.deploy = { };

  # Allow deploy user to run activation scripts as root without a password
  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Trust the deploy user in the Nix daemon so it can add paths to the store.
  # Explicitly include root to avoid losing it from the list (NixOS default is ["root"]).
  nix.settings.trusted-users = [
    "root"
    "deploy"
  ];
}
