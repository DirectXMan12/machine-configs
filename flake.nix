{
	description = "NixOS configuration";

	# use a released version
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-25.11";
		nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
		lanzaboote = {
			url = "github:nix-community/lanzaboote";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixpkgs-wayland.url = "github:nix-community/nixpkgs-wayland";
		nixos-sbc = {
			url = "github:nakato/nixos-sbc/main";
			inputs.nixpkgs.follows = "nixpkgs-unstable";
		};

		nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs-unstable";

    proxy-in-anger.url = "git+https://tangled.org/directxman12.dev/proxy-in-anger?ref=main";
    proxy-in-anger.inputs.nixpkgs.follows = "nixpkgs";
	};

	outputs = { self, nixpkgs, nixos-hardware, nixpkgs-unstable, lanzaboote, nixos-sbc, proxy-in-anger, ... }@attrs:
		let
			system = "x86_64-linux";
			overlays = {
				unstable-with-sway = final: prev: {
					unstable = import nixpkgs-unstable {
						system = "${prev.system}";
						config.allowUnfreePredicate = final.config.allowUnfreePredicate ;
						# overlay for using unstable-sway in sway-and-friends
						overlays = [ attrs.nixpkgs-wayland.overlay ];
					};
				};
				unstable-only = final: prev: {
					unstable = import nixpkgs-unstable {
						system = "${prev.system}";
						config.allowUnfreePredicate = final.config.allowUnfreePredicate;
					};
				};
			};

			mkSystem = {
				name,

				modules ? [],
				extra ? {},
				cfg ? {},
				unstable ? false,
			}: (if unstable then nixpkgs-unstable else nixpkgs).lib.nixosSystem {
				inherit system;
				modules = [
					./modules/utils/allowedUnfree-polyfill.nix
					./modules/common
					./modules/user-facing
					./modules/servers
					./modules/cache
					./shared-modules/serving
					./shared-modules/kanidm
					./shared-modules/copyparty
					./systems/${name}
					({ config, ... }: { config.local.unstable = unstable; })
					({ ... }: { networking.hostName = name; })
					({ config, pkgs, lib, ... }: {
						config.nixpkgs.overlays = lib.mkMerge [
							(lib.mkIf config.local.userFacing [ overlays.unstable-with-sway ])
							(lib.mkIf (!config.local.userFacing) [ overlays.unstable-only ])
							[
								# TODO: is there a better way to do this? maybe the overlays output?
								(final: prev: {
									proxy-in-anger = proxy-in-anger.packages.${prev.stdenv.hostPlatform.system}.default;
								})
							]
						];
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
					local.networking = "systemd";
					local.cache.enable = true;
				};
			};

			# sanctuary-router
			nixosConfigurations.sanctuary-router = mkSystem {
				name = "sanctuary-router";
				unstable = true;
				modules = [
						nixos-sbc.nixosModules.default
						nixos-sbc.nixosModules.boards.bananapi.bpir4
						nixos-sbc.nixosModules.cache
						./modules/router
				];
				cfg = {
					local.userFacing = false;
					local.uefi = false;
					local.networking = "systemd";
					local.cache.enable = true;
				};
			};

			nixosModules.default.imports = [
				./shared-modules/serving
				./shared-modules/kanidm
				./shared-modules/copyparty
			];
		};
}
