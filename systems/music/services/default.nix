{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
	imports = [
		./roon.nix
		./web.nix
		./home-assistant.nix
	];

	allowedUnfree = lib.mkAfter [
		"plexmediaserver"
		# temporary
		"unifi-controller"
		"mongodb-ce"
	];

	services.plex = {
		enable = true;
		openFirewall = true;
		package = pkgs.unstable.plex;
	};

	services.unifi = {
		enable = true;
		openFirewall = true;
		jrePackage = pkgs.jdk25_headless; # newer unifis need this, will be default in nixos 26.05
		unifiPackage = pkgs.unstable.unifi;
		mongodbPackage = pkgs.mongodb-ce;
	};

	# Open ports in the firewall.
	networking.firewall.allowedTCPPorts = [
		# unifi controller web
		8443

		# unifi remote management
		5349
	];
}
