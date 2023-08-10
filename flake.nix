{
	description = "NixOS configuration";

	# use a released version
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-23.05";
		nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
		lanzaboote = {
			url = "github:nix-community/lanzaboote";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";

		# only needed if you use as a package set:
		nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs-unstable";
	};

	outputs = { self, nixpkgs, nixos-hardware, nixpkgs-unstable, lanzaboote, ... }@attrs:
		let 
			system = "x86_64-linux";
			overlay-unstable = final: prev: {
				unstable = import nixpkgs-unstable {
					system = "${prev.system}";
					config.allowUnfreePredicate = pkg: builtins.elem (pkg.pname or (builtins.parseDrvName pkg.name).name) [
						"google-chrome-dev"
						"google-chrome"
						"google-chrome-beta"
					];
					# overlay for using unstable-sway in sway-and-friends
					overlays = [ attrs.nixpkgs-wayland.overlay ];
				};
			};

			commonModules = [
				# make pkgs.unstable available in modules
				({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })

				./configuration.nix
				./sway-and-friends.nix
				./common-system-apps.nix
				./audio.nix
			];

			x1Modules = commonModules ++ [
				./systems/yasamin/configuration.nix
				./systems/yasamin/hardware.nix
				nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
			];

			heresyModules = commonModules ++ [
				lanzaboote.nixosModules.lanzaboote
				./systems/heresy/configuration.nix
				./systems/heresy/hardware.nix
				nixos-hardware.nixosModules.lenovo-thinkpad-x1-extreme-gen4
			];

		in {
			nixosConfigurations.yasamin = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = x1Modules;
			};
			nixosConfigurations.yasamin-print = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = x1Modules ++ [
					({ pkgs, ... }: {
						services.printing.enable = true;
						# enable wifi printing
						services.avahi = {
							enable = true;
							nssmdns = true;
							openFirewall = true;
						};
					})
				];
			};
			nixosConfigurations.heresy = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = heresyModules;
			};
			nixosConfigurations.heresy-docker = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = heresyModules ++ [
					({ config, pkgs, ... }: {
						virtualisation.docker.enable = true;
						users.users.directxman12.extraGroups = [ "docker" ];
					})
				];
			};
		};
}
