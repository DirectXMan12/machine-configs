{ config, pkgs, lib, ... }:

with lib;
{
	config = mkIf config.local.userFacing {
		# use the shell from home-manager
		users.users.directxman12 = {
			shell = "/home/directxman12/.nix-profile/bin/zsh";
		};
	};
}
