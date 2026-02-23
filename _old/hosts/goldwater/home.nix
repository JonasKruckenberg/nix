{
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    #    syntaxHighlighting.enable = true;
    enableCompletion = true;
  };

  programs.git = {
    enable = true;
    userName = "JonasKruckenberg";
    userEmail = "iterpre@protonmail.com";
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

  home = {
    username = "jonaskruckenberg";
    homeDirectory = "/Users/jonaskruckenberg";

    packages = with pkgs; [
      gh
      rustup
      rustPlatform.bindgenHook

      jetbrains.rust-rover
    ];

    stateVersion = "25.11";
  };
}
