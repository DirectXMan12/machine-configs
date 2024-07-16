{ config, pkgs, ... }:

{
	boot = {
		# pretty boot
		plymouth = {
			enable = true;
			theme = "breeze";
		};
		initrd.systemd.enable = true; # pretty password prompt
		# TODO(directxman12): try out `initrd.systemd.enable` for password prompt in plymouth
		# (see https://github.com/NixOS/nixpkgs/issues/26722)
	};
}
