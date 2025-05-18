# krunner-rink

`krunner-rink` is a [KRunner](https://userbase.kde.org/Plasma/Krunner) plugin built with
[krunner-rs](https://github.com/pluiedev/krunner-rs) that provides matches using the open source unit-aware calculator
[Rink](https://crates.io/crates/rink). Also, like KDE's unit converter, Rink supports live currency conversion.

Compared to the built-in calculator and unit conversion apps, Rink (and therefore `krunner-rink`) has a much more
advanced parser for both queries and units, and presents numbers in a more human readable format.

## Examples

Repeating numbers comparison:

<p align="center">
    <img src="https://github.com/Naxdy/krunner-rink/blob/main/assets/repeating_numbers.png?raw=true" alt="Repeating numbers comparison" />
</p>

Rink knows a variety of commonly used constants:

<p align="center">
    <img src="https://github.com/Naxdy/krunner-rink/blob/main/assets/pi.png?raw=true" alt="pi" />
</p>

<p align="center">
    <img src="https://github.com/Naxdy/krunner-rink/blob/main/assets/e.png?raw=true" alt="e" />
</p>

From Rink's [crates.io page](https://crates.io/crates/rink): How much does it cost to run my computer each year? Say it
uses 100 watts for 4 hours per day, and use the US average electricity cost.

<p align="center">
    <img src="https://github.com/Naxdy/krunner-rink/blob/main/assets/pc_cost.png?raw=true" alt="electricity cost" />
</p>

## Installation

A `flake.nix` for installation using the [Nix](https://nixos.org) package manager is provided. You can install
`krunner-rink` using the following methods:

### Imperatively (nix profile)

```shell
nix profile install github:Naxdy/krunner-rink
```

### Declaratively (flakes)

Simply add this flake to your `inputs`, then either add its overlay to your `nixpkgs.overlays`, or directly add
`krunner-rink.packages.${system}.default` to your `systemPackages`, or your user's packages.

```nix
{
    inputs.krunner-rink.url = "github:Naxdy/krunner-rink";

    inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    outputs = { self, krunner-rink }: {
        nixosConfigurations.default = { pkgs, ... }: {
            nixpkgs.overlays = [
                krunner-rink.overlays.default
            ];

            environment.systemPackages = [
                pkgs.krunner-rink
            ];
        };
    };
}
```

### Installation without Nix

Since I only use NixOS, that's what I've packaged `krunner-rink` for. If you or someone else package `krunner-rink` for
a different distro, feel free to let me know, and I will link your package in this Readme.
