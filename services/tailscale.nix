{
  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--netfilter-mode=nodivert" ];
  };
}
