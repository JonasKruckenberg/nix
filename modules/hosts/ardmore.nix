{ inputs, config, ... }:
{
  # Asahi Mac mini, headless server. Pulls and applies main on a timer (system.autoUpgrade below).
  flake.nixosConfigurations.ardmore = inputs.nixpkgs.lib.nixosSystem {
    modules = [ config.flake.modules.nixos.ardmore ];
  };

  flake.modules.nixos.ardmore =
    { lib, modulesPath, ... }:
    {
      imports =
        (with config.flake.modules.nixos; [
          base
          jonas
          memark
          daxhuiberts
          tailscale
          observability
        ])
        ++ [
          inputs.apple-silicon-support.nixosModules.apple-silicon-support
          (modulesPath + "/installer/scan/not-detected.nix")
        ];

      networking.hostName = "ardmore";
      nixpkgs.hostPlatform = "aarch64-linux";
      system.stateVersion = "25.11";

      # Hardware
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "usbhid"
        "usb_storage"
      ];
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/f3d29c3a-6588-40ac-8f7c-e429fa5da4fb";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/8933-1D08";
        fsType = "vfat";
        options = [
          "fmask=0022"
          "dmask=0022"
        ];
      };
      # Apple peripheral firmware, pinned via the private ardmore-firmware input (see flake.nix).
      hardware.asahi.peripheralFirmwareDirectory = "${inputs.ardmore-firmware}/hosts/ardmore/firmware";

      boot.loader.systemd-boot.enable = true;
      boot.loader.systemd-boot.configurationLimit = 10;
      boot.loader.efi.canTouchEfiVariables = false;
      # Apple Silicon has read-only EFI vars and systemd >= 257 ignores --no-variables; keep
      # `bootctl update` non-fatal.
      boot.loader.systemd-boot.graceful = true;

      # Allow non-root perf.
      boot.kernel.sysctl."kernel.perf_event_paranoid" = -1;
      boot.kernel.sysctl."kernel.kptr_restrict" = lib.mkForce 0;

      time.timeZone = "Europe/Berlin";
      i18n.defaultLocale = "en_US.UTF-8";
      i18n.extraLocaleSettings.LC_ALL = "en_US.UTF-8";
      console.keyMap = "de-latin1-nodeadkeys";

      # Continuous deployment by pulling: every hour fetch main from GitHub, build, switch. CI builds
      # this configuration on every PR, so gate merges on it (branch protection) and this never
      # switches into a broken generation.
      system.autoUpgrade = {
        enable = true;
        flake = "github:JonasKruckenberg/nix#ardmore";
        dates = "hourly";
      };
    };
}
