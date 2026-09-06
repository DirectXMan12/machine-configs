{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
	imports = [
		./hardware.nix
		./services
	];

	### networking setup
	systemd.network = {
		networks = {
			"30-wired-lan" = {
				matchConfig.Name = "eno1";
				vlan = [ "wlan-vlan" "lan-vlan" ];
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
			};
			"40-wlan-vlan" = {
				matchConfig.Name = "wlan-vlan";
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
			};
			"41-lan-vlan" = {
				matchConfig.Name = "lan-vlan";
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
				routes = [{
					# ip route add fd2f:fb3a:f99a:1::/64 nexthop via fe80::4073:e7ff:fe87:6614 dev lan-vlan
					Destination = "fd2f:fb3a:f99a:1::/64";
					Gateway = "fe80::4073:e7ff:fe87:6614";
				}];
			};
		};

		# join to the wlan vlan for roon stuff, since roon can't discover cross-vlan
		netdevs = {
			"20-wlan-vlan-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "wlan-vlan";
				};
				vlanConfig.Id = 2;
			};
			"21-lan-vlan-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "lan-vlan";
				};
				vlanConfig.Id = 1;
			};
		};
		# use stable ipv6 addresses only (part 1)
		config.networkConfig.IPv6PrivacyExtensions = false;	
	};

	# screws up matter royally to have this on
	services.resolved.settings.Resolve.MulticastDNS = false;

	# use stable ipv6 addresses only (part 2)
	networking.tempAddresses = "disabled";

	# only on the specified adapters
	networking.useDHCP = false;
	networking.nftables.enable = true;


	# This option defines the first version of NixOS you have installed on this particular machine,
	# and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
	#
	# Most users should NEVER change this value after the initial install, for any reason,
	# even if you've upgraded your system to a new NixOS release.
	#
	# This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
	# so changing it will NOT upgrade your system.
	#
	# This value being lower than the current NixOS release does NOT mean your system is
	# out of date, out of support, or vulnerable.
	#
	# Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
	# and migrated your data accordingly.
	#
	# For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
	system.stateVersion = "23.11"; # Did you read the comment?
}
