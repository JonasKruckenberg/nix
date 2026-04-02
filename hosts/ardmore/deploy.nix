{ ... }:
{
  # SSH daemon — required for nixos-rebuild --target-host
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Dedicated CI deploy user.
  # Generate a key pair with:
  #   ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key
  # Then:
  #   - Add the private key as the DEPLOY_SSH_PRIVATE_KEY GitHub Actions secret
  #   - Replace the placeholder below with the contents of deploy_key.pub and redeploy manually once
  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    openssh.authorizedKeys.keys = [
      # REPLACE with your actual public key before first deployment
      # "ssh-ed25519 AAAA... github-actions-deploy"
    ];
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

  # Trust the deploy user in the Nix daemon so it can add paths to the store
  nix.settings.trusted-users = [ "deploy" ];
}
