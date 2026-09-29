{
  description = "Jonas' multi-host Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support = {
      url = "github:nix-community/nixos-apple-silicon/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bulletin = {
      url = "github:JonasKruckenberg/bulletin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Apple peripheral firmware for ardmore (all_firmware.tar.gz + kernelcache), extracted from the
    # machine's EFI partition by the Asahi installer. Apple's blobs are not redistributable, so they
    # live in a private repo; this lock pins their revision and content hash, the bytes stay out of
    # this public tree. Not LFS: `github:` inputs are fetched as tarballs, which omit LFS content.
    # TEMPORARY: pinned to the last commit of this repo that still carried the blobs, so CI can
    # validate the rest of the tree. Switch to github:JonasKruckenberg/ardmore-firmware once that
    # private repo exists and the CI token covers it, then drop the subpath in modules/hosts/ardmore.nix.
    ardmore-firmware = {
      url = "github:JonasKruckenberg/nix/024fa60";
      flake = false;
    };
  };

  # Dendritic layout: every file under ./modules is a flake-parts module. Features publish
  # NixOS / nix-darwin / home-manager modules into `flake.modules.<class>.<name>`; hosts under
  # modules/hosts compose them. Paths containing `/_` are not imported.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
