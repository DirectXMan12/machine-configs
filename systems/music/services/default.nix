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
		package = pkgs.plex.overrideAttrs (final: old: {
			version = "1.41.0.8994-f2c27da23";
			src = pkgs.fetchurl {
				url = "https://downloads.plex.tv/plex-media-server-new/${final.version}/debian/plexmediaserver_${final.version}_amd64.deb";
				sha256 = "sha256-e1COeawdR0pCF+qQ/xkTn/716iM9kB/fXom5MWHQ0YI=";
			};
		});
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
