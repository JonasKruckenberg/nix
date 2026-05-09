_: {
  programs.git = {
    enable = true;
    settings.user = {
      name = "JonasKruckenberg";
      email = "iterpre@protonmail.com";
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "JonasKruckenberg";
        email = "iterpre@protonmail.com";
      };
      git = {
        write-change-id-header = true;
      };
      signing = {
        behavior = "own";
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
      };
    };
  };
}
