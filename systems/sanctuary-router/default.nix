{ config, pkgs, lib, ... }:

{
	imports = [
		#./routing-and-firewall.nix
		./routing-and-firewall.redux.nix
	];
	sbc = {
		version = "0.3";
		filesystem.useDefaultLayout = "btrfs-subvol";
	};
	nixpkgs.hostPlatform.system = "aarch64-linux";

	# actual system stuff
	services.openssh = {
		enable = true;
		settings.PermitRootLogin = "yes"; # TODO: temporary
	};
	networking.hostName = "sanctuary-router";

	boot.kernelPatches = [
		{
			patch = null;
			extraStructuredConfig = with lib.kernel; {
				WIREGUARD = module;
			};
		}
	];

	# TODO: wireguard
	# TODO: dhcp-v4
	# TODO: ipv6 networking check?
	# TODO: firewall & nat
	# TODO: dns resolver (unbound)
	# TODO: dashboard (prometheus metrics)
	# TODO: dns blocker
	# TODO: igmp proxy?
	# TODO: udp boradcast relay
	# TODO: avahi & mdns?
	# TODO: vlan setup
	# TODO: ddns
	
	# This value determines the NixOS release from which the default
	# settings for stateful data, like file locations and database versions
	# on your system were taken. It‘s perfectly fine and recommended to leave
	# this value at the release version of the first install of this system.
	# Before changing this value read the documentation for this option
	# (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
	system.stateVersion = "25.05"; # Did you read the comment?

}
