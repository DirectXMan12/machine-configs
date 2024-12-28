{
	description = "NixOS configuration";

	# use a released version
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-24.11";
		nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
		lanzaboote = {
			url = "github:nix-community/lanzaboote";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
		nixos-sbc.url = "github:nakato/nixos-sbc/main";

		nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs-unstable";
		nixos-sbc.inputs.nixpkgs.follows = "nixpkgs-unstable";
	};

	outputs = { self, nixpkgs, nixos-hardware, nixpkgs-unstable, lanzaboote, nixos-sbc, ... }@attrs:
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

			mkSystem = {
				name,

				modules ? [],
				extra ? {},
				cfg ? {},
			}: nixpkgs.lib.nixosSystem {
				inherit system;
				modules = [
					./modules/utils/allowedUnfree-polyfill.nix
					./modules/common
					./modules/user-facing
					./systems/${name}
					({ ... }: { networking.hostName = name; })
					({ config, pkgs, lib, ... }: {
						config = lib.mkIf config.local.userFacing {
							# make pkgs.unstable available in modules
							nixpkgs.overlays = [ overlay-unstable-with-sway ];
						};
					})
					({ ... }: cfg)
				] ++ modules;
			} // extra;
		in rec {
			# yasamin
			nixosConfigurations.yasamin = mkSystem {
				name = "yasamin";
				modules = [
					nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
				];
				cfg = {
					local.userFacing = true;
				};
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

			# music.devices
			nixosConfigurations.music = mkSystem {
				name = "music";
				cfg = {
					local.userFacing = false;
				};
			};

			# sanctuary-router
			nixosConfigurations.sanctuary-router = mkSystem {
				name = "sanctuary-router";
				modules = [
						nixos-sbc.nixosModules.default
						nixos-sbc.nixosModules.boards.bananapi.bpir4
						nixos-sbc.nixosModules.cache
				];
				cfg = {
					local.userFacing = false;
					local.uefi = false;
					local.networking = "systemd";
				};
			};
		};
}
