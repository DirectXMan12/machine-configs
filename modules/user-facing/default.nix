{ lib, ... }:

with lib;
{
	imports = [
		./boot.nix
		./home-manager-systems.nix
		./sway-and-friends.nix
		./common-system-apps.nix
	];

	options = {
		local.userFacing = mkOption {
			type = types.bool;
			default = false;
			description = "is this a user-facing system";
		};
	};
}
