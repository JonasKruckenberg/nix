_: {
  flake.modules.homeManager.shell = {
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      enableCompletion = true;
    };
  };
}
