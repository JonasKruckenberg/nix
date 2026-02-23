{ inputs, ... }:
{
  easy-hosts = {
    path = ./.;

    shared = {
      modules = [
        inputs.self.commonModules.default
      ];
    };

    hosts = {
      # keep-sorted start block=yes newline_separated=yes
      ardmore = {
        arch = "aarch64";
        class = "nixos";
        modules = [
          inputs.home-manager.nixosModules.home-manager
          inputs.self.nixosModules.user
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          }
        ];
      };

      goldwater = {
        arch = "aarch64";
        class = "darwin";
        modules = [
          inputs.home-manager.darwinModules.home-manager
          inputs.self.darwinModules.system-defaults
          inputs.self.darwinModules.user
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.jonaskruckenberg = import ./goldwater/home.nix;
          }
        ];
      };
      # keep-sorted end
    };
  };
}
