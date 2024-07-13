{ config, pkgs, ... }:

{
	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	# Use the systemd-boot EFI boot loader.
	boot = {
		# pretty boot
		plymouth = {
			enable = true;
			theme = "breeze";
		};
		initrd.systemd.enable = true; # pretty password prompt

		# TODO(directxman12): try out `initrd.systemd.enable` for password prompt in plymouth
		# (see https://github.com/NixOS/nixpkgs/issues/26722)

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
