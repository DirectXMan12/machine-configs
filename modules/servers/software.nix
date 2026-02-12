{ config, pkgs, ... }:

{
	environment.systemPackages = with pkgs; [
		# common stuff that's not here because we're not using home-manager,
		# but also not considered emergency for inclusion in base

		nushell
	];
}
