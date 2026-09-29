# nix

One flake, every machine. Layout follows the [dendritic pattern](https://github.com/mightyiam/dendritic):
each file in `modules/` is a flake-parts module that publishes one feature into
`flake.modules.{nixos,darwin,homeManager}.<name>`; hosts in `modules/hosts/` compose features.

| Host      | Kind                    | Apply                                                                        |
| --------- | ----------------------- | ---------------------------------------------------------------------------- |
| ardmore   | NixOS, Asahi Mac mini   | pulls `main` hourly by itself (`system.autoUpgrade`)                         |
| goldwater | nix-darwin, MacBook     | `sudo darwin-rebuild switch --flake github:JonasKruckenberg/nix#goldwater`   |
| work      | home-manager, MacBook   | `nix run home-manager -- switch --flake github:JonasKruckenberg/nix#work`    |

CI builds every configuration for its system on every PR (`nix flake check`). Format with `nix fmt`.
