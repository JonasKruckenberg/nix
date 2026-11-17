# nix

One flake, every machine. Layout follows the [dendritic pattern](https://github.com/mightyiam/dendritic):
each file in `modules/` is a flake-parts module that publishes one feature into
`flake.modules.{nixos,darwin,homeManager}.<name>`; hosts in `modules/hosts/` compose features.

| Host      | Kind                    | Apply                                                                        |
| --------- | ----------------------- | ---------------------------------------------------------------------------- |
| ardmore   | NixOS, Asahi Mac mini   | pulls `main` hourly by itself (`system.autoUpgrade`)                         |
| goldwater | nix-darwin, MacBook     | `sudo darwin-rebuild switch --flake github:JonasKruckenberg/nix#goldwater`   |
| work      | home-manager, MacBook   | `nix run home-manager -- switch --flake github:JonasKruckenberg/nix#work`    |

CI runs `nix flake check` on every PR: the darwin configurations are built, ardmore is evaluated (its Asahi kernel is
not in any binary cache and builds on the device). Format with `nix fmt`.
