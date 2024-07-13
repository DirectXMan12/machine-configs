{
	description = "NixOS configuration";

	# use a released version
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-24.05";
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
			overlay-unstable-with-sway = final: prev: {
				unstable = import nixpkgs-unstable {
					system = "${prev.system}";
					config.allowUnfreePredicate = pkg: builtins.elem (pkg.pname or (builtins.parseDrvName pkg.name).name) final.allowedUnfree;
					# overlay for using unstable-sway in sway-and-friends
					overlays = [ attrs.nixpkgs-wayland.overlay ];
				};
			};

			mkSystem = { name, userFacing, modules ? [], extra ? {} }: nixpkgs.lib.nixosSystem {
				inherit system;
				modules = [
					./allowedUnfree-polyfill.nix
					./configuration.nix
					./systems/${name}/configuration.nix
					./systems/${name}/hardware.nix
				] ++ modules ++ nixpkgs.lib.optionals (userFacing) [
					# make pkgs.unstable available in modules
					({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable-with-sway ]; })
					./home-manager-systems.nix
					./sway-and-friends.nix
					./common-system-apps.nix
				];
			} // extra;
		in rec {
			nixosConfigurations.yasamin = mkSystem {
				name = "yasamin";
				userFacing = true;
				modules = [
					nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
				];
			};
			nixosConfigurations.yasamin-print = nixosConfigurations.yasamin // {
				modules = nixpkgs.lib.mkAfter [
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

			nixosConfigurations.heresy = mkSystem {
				name = "heresy";
				userFacing = true;
				modules = [
					lanzaboote.nixosModules.lanzaboote
					nixos-hardware.nixosModules.lenovo-thinkpad-x1-extreme-gen4
				];
			};
			nixosConfigurations.heresy-docker = nixosConfigurations.heresy // {
				modules = nixpkgs.lib.mkAfter [
					({ config, pkgs, ... }: {
						virtualisation.docker.enable = true;
						users.users.directxman12.extraGroups = [ "docker" ];
					})
				];
			};

			nixosConfigurations.music = mkSystem {
				name = "music";
				userFacing = false;
			};
		};
}
