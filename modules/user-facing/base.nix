{ config, pkgs, lib, ... }:

{
	config = lib.mkIf config.local.userFacing {
		# automatically determine our timezone
		services.automatic-timezoned.enable = true;
	};
}
