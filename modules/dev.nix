_: {
  # Baseline development tooling for every human account.
  flake.modules.homeManager.dev =
    { pkgs, ... }:
    {
      programs.git.enable = true;
      programs.gh.enable = true;
      home.packages = with pkgs; [
        rustup
        rustPlatform.bindgenHook
      ];
    };
}
