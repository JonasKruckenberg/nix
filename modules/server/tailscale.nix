_: {
  flake.modules.nixos.tailscale =
    { config, ... }:
    {
      services.tailscale = {
        enable = true;
        extraSetFlags = [
          "--netfilter-mode=nodivert"
          "--ssh" # Tailscale SSH replaces OpenSSH for remote access
        ];
      };

      networking.nftables.enable = true;
      networking.firewall = {
        enable = true;
        trustedInterfaces = [ "tailscale0" ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };

      # Force tailscaled onto nftables; avoids the iptables-compat translation layer.
      systemd.services.tailscaled.serviceConfig.Environment = [ "TS_DEBUG_FIREWALL_MODE=nftables" ];

      # Don't block boot on network-online with a VPN in the path.
      systemd.network.wait-online.enable = false;
      boot.initrd.systemd.network.wait-online.enable = false;
    };
}
