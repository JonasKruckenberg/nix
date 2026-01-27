{ config, ... }:
{
  services.tailscale = {
    enable = true;
  extraSetFlags = [ "--netfilter-mode=nodivert" ];
  };
  networking.firewall = {
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
    checkReversePath = "loose";
  };
}
