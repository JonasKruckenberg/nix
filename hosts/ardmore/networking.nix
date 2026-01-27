{ lib, pkgs, ... }:
{
  networking = {
    hostName = "ardmore";
    enableIPv6 = true;
    useDHCP = lib.mkDefault true;

    networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

    # Use IWD as the backend for networkmanager. We need this because
    # it supports the broadcom wifi chips used in macs
    wireless.iwd = {
      enable = true;
      settings = {
        General = {
          EnableNetworkConfiguration = true;
        };
        Network = {
          EnableIPv6 = true;
        };
        Settings = {
          AutoConnect = true;
        };
      };
    };
  };
}
