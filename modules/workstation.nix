{ config, ... }:
{
  # Interactive machines: macOS defaults, GUI apps, editors. Servers never import this.
  flake.modules = {
    darwin.workstation = {
      home-manager.sharedModules = [ config.flake.modules.homeManager.workstation ];

      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = false;
          upgrade = false;
        };
        casks = [
          "github"
          "ungoogled-chromium"
        ];
      };

      system.defaults = {
        iCal = {
          "TimeZone support enabled" = true;
          "first day of week" = "Monday";
        };

        finder = {
          AppleShowAllFiles = true;
          AppleShowAllExtensions = true;
          FXEnableExtensionChangeWarning = false;
          ShowStatusBar = false;
          ShowPathbar = true;
        };

        NSGlobalDomain = {
          AppleShowAllFiles = true;
          AppleShowAllExtensions = true;
          AppleInterfaceStyleSwitchesAutomatically = true;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          AppleMetricUnits = 1;
        };
      };
    };

    homeManager.workstation =
      { pkgs, lib, ... }:
      {
        home.packages = lib.optionals pkgs.stdenv.isDarwin [ pkgs.jetbrains.rust-rover ];
      };
  };
}
