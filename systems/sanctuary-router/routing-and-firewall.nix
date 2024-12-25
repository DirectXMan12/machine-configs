{ config, pkgs, lib, ... }:

{
	# tell the kernel that it's okay to forward traffic,
	# cause this is an essential function of a router
	boot.kernel = {
		sysctl = {
			"net.ipv4.conf.all.forwarding" = true;
			"net.ipv6.conf.all.forwarding" = true;
		};
	};

	# TODO: systemd.network for interfaces

	networking = {
		# we'll configure this per-interface above in systemd.network
		useDHCP = false;

		# TODO: should we disable firewall?
		# TODO: nat settings (does this go through firewall?  it might be too simple, consider nixos-nftables-firewall)

		nftables = {
			enable = true;
		};
	};
}
