{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gh
    rustup
    rustPlatform.bindgenHook
    croc
    claude-code
  ];
}
