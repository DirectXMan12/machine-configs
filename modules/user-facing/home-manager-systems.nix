{ config, pkgs, lib, ... }:

with lib;
{
	config = mkIf config.local.userFacing {
		environment.shells = lib.attrsets.mapAttrsToList (_: userConfig: "${userConfig.home}/.nix-profile/bin/nu") config.users.users;
	};
}
