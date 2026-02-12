{ lib, config, ... }:

with lib;
{
	imports = [
		./sso-pam.nix
	];

	options = {
		local.server.enable = mkOption {
			type = types.bool;
			default = !config.local.userFacing;
			description = "is a server";
		};
	};
}
