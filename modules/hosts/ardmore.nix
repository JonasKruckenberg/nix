{ inputs, config, ... }:
{
  # Asahi Mac mini, headless server. Deployed by .github/workflows/deploy.yml over Tailscale SSH.
  flake.nixosConfigurations.ardmore = inputs.nixpkgs.lib.nixosSystem {
    modules = [ config.flake.modules.nixos.ardmore ];
  };

  flake.modules.nixos.ardmore =
    {
      lib,
      pkgs,
      modulesPath,
      ...
    }:
    {
      imports =
        (with config.flake.modules.nixos; [
          base
          jonas
          memark
          daxhuiberts
          tailscale
          observability
          bulletin
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
      hardware.asahi.peripheralFirmwareDirectory = inputs.ardmore-firmware;
      # Exposes the Mesa Asahi Vulkan ICD under /run/opengl-driver for the llama.cpp sidecar.
      hardware.graphics.enable = true;

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

      # agenix identity. Tailscale SSH replaces OpenSSH here, so agenix cannot derive a key from
      # services.openssh.hostKeys; this key was generated once on the box.
      age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # CI deploy user: nixos-rebuild --target-host/--build-host as this user, activation via sudo.
      users.users.deploy = {
        isSystemUser = true;
        group = "deploy";
        shell = pkgs.zsh;
      };
      users.groups.deploy = { };
      security.sudo.extraRules = [
        {
          users = [ "deploy" ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      nix.settings.trusted-users = [
        "root"
        "deploy"
      ];
    };
}
