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

    # Secrets, age-encrypted in ./secrets to the hosts that read them; see secrets/secrets.nix.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private: fetching it needs a token, on ardmore (secrets/github-token.conf.age) and in CI.
    # Its `main`, for the metafactory (modules/server/metafactory.nix). nixpkgs follows ours.
    refractory = {
      url = "github:JonasKruckenberg/refractory/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support = {
      url = "github:nix-community/nixos-apple-silicon/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Dendritic layout: every file under ./modules is a flake-parts module. Features publish
  # NixOS / nix-darwin / home-manager modules into `flake.modules.<class>.<name>`; hosts under
  # modules/hosts compose them. Paths containing `/_` are not imported.
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
