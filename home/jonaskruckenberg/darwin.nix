{ pkgs, lib, ... }:
{
  home.packages = lib.mkIf pkgs.stdenv.isDarwin (
    with pkgs;
    [
      jetbrains.rust-rover
    ]
  );
}
