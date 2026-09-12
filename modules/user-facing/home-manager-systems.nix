{ config, pkgs, lib, ... }:

with lib;
{
	config = mkIf config.local.userFacing {
	};
}
