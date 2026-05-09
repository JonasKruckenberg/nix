{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    rustPlatform.bindgenHook
    croc
    claude-code
  ];
}
