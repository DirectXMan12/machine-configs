{ config, pkgs, ... }:

{
	# Use the systemd-boot EFI boot loader.
	boot = {
		# actual boot details
		loader = {
			systemd-boot = {
				enable = true;
				consoleMode = "auto"; # a slightly higher resolution, hopefully
			};
			efi.canTouchEfiVariables = true;
		};
	};
}
