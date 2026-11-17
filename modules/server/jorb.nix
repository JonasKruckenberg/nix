_: {
  # jorb's own filesystem: XFS at /var/lib/jorb, in a sparse 60G image on the root filesystem.
  # Only the storage so far; the service that uses it comes later.
  flake.modules.nixos.jorb =
    { pkgs, ... }:
    {
      # Runs once per machine: an existing image is never touched. Built under a temporary name
      # and renamed, so an interrupted run leaves no half-made image to mount.
      systemd.services.jorb-image = {
        description = "Create the jorb XFS image if absent";
        unitConfig = {
          # The mount below is part of local-fs.target, which default dependencies would order
          # this unit after.
          DefaultDependencies = false;
          RequiresMountsFor = "/var/lib";
          ConditionPathExists = "!/var/lib/jorb.img";
        };
        serviceConfig.Type = "oneshot";
        path = [ pkgs.xfsprogs ];
        script = ''
          truncate -s 60G /var/lib/jorb.img.tmp
          mkfs.xfs -f -q -L jorb /var/lib/jorb.img.tmp
          chmod 600 /var/lib/jorb.img.tmp
          mv /var/lib/jorb.img.tmp /var/lib/jorb.img
        '';
      };

      # `nofail`: a missing or broken image must not drop this headless host into emergency mode.
      # `discard` punches freed blocks out of the image, so it stays sparse. `noCheck`: fsck.xfs
      # does nothing, and asking for it on a file makes systemd-fstab-generator warn on every
      # daemon-reload.
      fileSystems."/var/lib/jorb" = {
        device = "/var/lib/jorb.img";
        fsType = "xfs";
        noCheck = true;
        options = [
          "loop"
          "nofail"
          "discard"
          "x-systemd.requires=jorb-image.service"
        ];
      };
    };
}
