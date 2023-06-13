{ config, pkgs, ... }:

{
	networking.hostName = "heresy"; # Define your hostname.

	# mimic the old 22.11 hidpi settings (fontconfig & console settings)
	fonts.fontconfig = {
		# TODO: current recs say false for antialias, this is just a
		# holdover -- see nixos/nixpkgs#222236
		antialias = true;
		subpixel = { rgba = "none"; lcdfilter = "none"; };
	};
	console.font = "${pkgs.terminus_font}/share/consolefonts/ter-v32n.psf.gz";
	console.earlySetup = true; # from 22.11, for full disk encryption passwords

	# secureboot
	environment.systemPackages = with pkgs; [
		sbctl
	];
	boot.bootspec.enable = true;
	boot.lanzaboote = {
		enable = true;
		pkiBundle = "/etc/secureboot";
	};
	boot.loader.systemd-boot.enable = pkgs.lib.mkForce false;


	# nvidia
	hardware.nvidia.modesetting.enable = true; # for sway, I believe
	# the rest is from nixos-hardware, enabled via modules
	boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_3; # for nouveau support for my gpu
	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It's perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "23.05"; # Did you read the comment?
}
