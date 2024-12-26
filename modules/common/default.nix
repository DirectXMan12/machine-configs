{ config, lib, ... }:

with lib;
{
	imports = [
		./base.nix
		./users.nix
		./uefi.nix
	];

	options = {
		local.uefi = mkOption {
			type = types.bool;
			default = true;
			description = "use uefi (enables systemd boot when local.userFacing is enabled)";
		};
		local.networking = mkOption {
			type = types.enum ["networkmanager" "systemd"];
			default = "networkmanager";
			description = "which networking setup to use";
		};
	};

	# TODO: refactor this into a separate module
	config = mkIf (config.local.networking == "networkmanager") {
		networking.networkmanager.enable = true;
	};
}
