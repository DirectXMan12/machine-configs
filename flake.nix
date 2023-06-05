{
	description = "NixOS configuration";

	# use a released version
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-22.11";
		nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
	};

	outputs = { self, nixpkgs, nixos-hardware, nixpkgs-unstable, ... }@attrs:
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
				};
			};

			commonModules = [
				# make pkgs.unstable available in modules
				({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })

				./sway-and-friends.nix
				./common-system-apps.nix
			];

			x1Modules = commonModules ++ [
				./configuration.nix
				nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
			];

		in {
			nixosConfigurations.yasamin = nixpkgs.lib.nixosSystem {
				inherit system;
				inherit modules;
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
			nixosConfiguration.heresy = nixpkgs.lib.nixosSystem {
				inherit system;
				modules = commonModules ++ [

				];
			};
		};
}
