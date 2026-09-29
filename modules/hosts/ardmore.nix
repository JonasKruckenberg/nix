{ inputs, config, ... }:
let
  inherit (config.flake) modules;
in
{
  # Asahi Mac mini, headless server. Pulls and applies main on a timer (system.autoUpgrade below).
  flake.nixosConfigurations.ardmore = inputs.nixpkgs.lib.nixosSystem {
    modules = [ modules.nixos.ardmore ];
  };

  flake.modules.nixos.ardmore =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    let
      firmwareFound = config.hardware.asahi.peripheralFirmwareDirectory != null;
    in
    {
      imports =
        (with modules.nixos; [
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
      # Apple's peripheral firmware is not redistributable, so it is not in this repo. The Asahi
      # module's default finds it on the machine's own ESP (/boot/asahi), which needs an impure
      # evaluation; pure builds elsewhere (CI) find nothing and produce a system without it.
      hardware.asahi.extractPeripheralFirmware = firmwareFound;
      warnings = lib.optional (!firmwareFound) "ardmore: Asahi firmware not found; on the device, build with --impure";

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
        flags = [ "--impure" ]; # firmware from the ESP, see hardware.asahi above
        dates = "hourly";
      };
    };
}
