{ config, pkgs, lib, ... }:

{
	imports = [
		./routing-and-firewall.nix
	];
	sbc = {
		version = "0.3";
		filesystem.useDefaultLayout = "btrfs-subvol";
	};
	nixpkgs.hostPlatform.system = "aarch64-linux";

	# actual system stuff
	services.openssh = {
		enable = true;
	};
	networking.hostName = "sanctuary-router";

	boot.kernelPatches = [
		{
			patch = null;
			structuredExtraConfig = with lib.kernel; {
				WIREGUARD = module;
			};
		}
	];

	services.oink = {
		enable = true;
		domains = [
			{ domain = "metamagical.house"; subdomain = "tunnel"; }
			# ipv6 is set on the actual machine, since we're using the real ipv6 addr
			{ domain = "metamagical.house"; subdomain = "sso"; skipIPv6 = true; }
			# set this up so we can just have cnames, since basically everything works like sso
			{ domain = "metamagical.house"; subdomain = "_services"; skipIPv6 = true; }
		];
		secretApiKeyFile = "/etc/keys/oink.secret-key";
		apiKeyFile = "/etc/keys/oink.key";
	};

	# only allow admins on the router
	local.server.pam.login-groups = ["pam_admins"];

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

	environment.systemPackages = with pkgs; [
		# stuff that's nice to have in an emergency, if the network is down
		tcpdump
		dig
		usbutils # lsusb
		pciutils # lspci
	];
}
