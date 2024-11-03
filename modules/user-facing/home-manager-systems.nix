{ config, pkgs, lib, ... }:

{
	# use the shell from home-manager
	users.users.directxman12 = {
		shell = "/home/directxman12/.nix-profile/bin/zsh";
	};
}
