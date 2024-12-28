{ config, pkgs, lib, ... }:

{
	imports = [
		./custom-bind.nix
	];
	# tell the kernel that it's okay to forward traffic,
	# cause this is an essential function of a router
	boot.kernel = {
		sysctl = {
			"net.ipv4.conf.all.forwarding" = true;
			"net.ipv6.conf.all.forwarding" = true;
		};
	};

	# TODO: missing wireguard support from the kernel, will need to rebuild

	# network interfaces
	systemd.network = {
		# these names are consistent, but let's make them a bit more readable
		links = {
			"10-eth1-to-sfp0" = {
				matchConfig.OriginalName = "eth1";
				linkConfig.Name = "sfp0";
			};
			"10-eth2-to-spf1" = {
				matchConfig.OriginalName = "eth2";
				linkConfig.Name = "sfp1";
			};
			"10-eth0-to-switch0" = {
				matchConfig.OriginalName = "eth0";
				linkConfig.Name = "switch0";
			};
		};
		networks = {
			# physical
			"30-spf1-wan" = {
				# TODO: block private networks and loopback addresses, and also bogon networks?
				# (are these also called martian addresses)
				matchConfig.Name = "sfp1";
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				linkConfig.RequiredForOnline = "routable";
			};
			"30-sfp0-lan" = {
				matchConfig.Name = "spf0";
				vlan = [ "vlan2-wlan" "vlan3-iot" ];
				# TODO v6 prefix delegation (via kea?)
				address = [
					"192.168.1.1/24"
				];
				linkConfig.RequiredForOnline = "routable";
			};

			# vlans
			"40-wlan-vlan" = {
				matchConfig.Name = "vlan2-wlan";
				# TODO v6 prefix delegation (via kea?)
				address = [
					"192.168.2.1/24"
				];
			};
			"40-iot-vlan" = {
				matchConfig.Name = "vlan3-iot";
				# TODO v6 prefix delegation (via kea?)
				address = [
					"192.168.3.1/24"
				];
			};
		};
		netdevs = {
			"20-wlan-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "vlan2-wlan";
				};
				vlanConfig.Id = 2;
			};
			"20-iot-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "vlan3-iot";
				};
				vlanConfig.Id = 3;
			};
		};
	};

	# DHCP
	services.kea = {
		dhcp-ddns = {
			enable = true;
			settings = {
				forward-dns = {
					ddns-domains = [
						{
							name = "home.metamagical.dev.";
							dns-servers = [{ip-address = "127.0.0.1";}];
						}
						{
							name = "w.home.metamagical.dev.";
							dns-servers = [{ip-address = "127.0.0.1";}];
						}
					];
				};
				# TODO: reverse-dns
			};
		};
		dhcp4 = {
			enable = true;
			settings = {
				# TODO: check these from pfsense
				# TODO: pfsense says: default lease: 7200, max lease: 86400
				valid-lifetime = 7200;
				max-valid-lifetime = 86400;

				interfaces-config.interfaces = ["sfp0" "vlan2-wlan" "vlan3-iot"];
				lease-database = {
					type = "memfile";
					persist = true;
					name = "/var/lib/kea/dhcp4.leases";
				};
				hosts-database = {
					# TODO: for syncing to dns? or just use dhcp-ddns
				};
				dhcp-ddns = {
					enable-updates = true;
				};

				subnet4 = [
					{
						id = 1;
						subnet = "192.168.1.1/24";
						pools = [{pool = "192.168.1.100 - 192.168.1.245";}];
						ddns-qualifying-suffix = "home.metamagical.dev";
						option-data = [
							{name = "domain-name-servers"; data = "192.168.1.1";}
							{name = "domain-search"; data = "home.metamagical.dev";}
						];
						reservations = [
							# desktop, 2.5gbe (:98 is 1gbe)
							{ hw-address = "24:4b:fe:4f:ba:99"; ip-address = "192.168.1.2"; hostname = "solly-custompc"; }
							# .3 was xyrithes
							{ hw-address = "0c:ea:14:1a:46:ab"; ip-address = "192.168.1.4"; hostname = "main-switch"; }
							# music (wired)
							{ hw-address = "54:b2:03:94:0d:30"; ip-address = "192.168.1.5"; hostname = "music"; }
							# living room U7 Pro AP (on the lan)
							{ hw-address = "28:70:4e:d5:38:83"; ip-address = "192.168.1.6"; hostname = "living-room-ap"; }
						];
					}
					{
						id = 2;
						subnet = "192.168.2.1/24";
						ddns-qualifying-suffix = "w.home.metamagical.dev";
						# TODO: search list (home.metamagical.dev)
						pools = [{pool = "192.168.2.100 - 192.168.2.245";}];
						option-data = [
							{name = "domain-name-servers"; data = "192.168.2.1";}
							{name = "domain-search"; data = "home.metamagical.dev";}
						];
						reservations = [
							# .3 was xyrithes
							# music (wlan vlan via wired)
							{ hw-address = "54:b2:03:94:0d:30"; ip-address = "192.168.2.4"; hostname = "music"; }
							{ hw-address = "d8:3a:dd:bc:04:87"; ip-address = "192.168.2.5"; hostname = "living-room-roon-bridge"; }
							# living room U7 Pro AP (on the wlan)
							{ hw-address = "28:70:4e:d5:38:83"; ip-address = "192.168.2.6"; hostname = "living-room-ap"; }
						];
					}
					{
						id = 3;
						subnet = "192.168.3.1/24";
						ddns-qualifying-suffix = "devices.home.metamagical.dev";
						option-data = [
							{name = "domain-name-servers"; data = "192.168.3.1";}
						];
						pools = [{pool = "192.168.3.100 - 192.168.3.245";}];
					}
				];
			};
		};
	};

	# internal dns provider
	# TODO: i'd love to use hickory for everything, but it doesn't support views yet,
	# and we need those for some DNS trickery that we're doing
	# wow the bind setup in nixpkgs is... restrictive.
	# we should PR things into nixpkgs to fix it, and also the outdated terminology
	# for now, we'll use our own
	local.services.bind = {
		enable = true;
		# TODO: listen on ipv6
		listenOn = [ "127.0.0.1" "192.168.0.0/16" ];
		# TODO: allow-update on appropriate zones
		# TODO: acl to be extra sure?
		# TODO: listen on wireguard interface too?

		zones = {
			# TODO: file bug asking for a namedb package
			"." = {
				type = "hint";
				file = pkgs.fetchurl {
					url = "https://www.internic.net/domain/named.root";
					hash = "sha256-Q6fzqK8cPPuEF75BvyV16JcKhzvqFNEjEuER3SZ1R6U=";
				};
			};
			# dhcp-ddns zones
			"home.metamagical.dev" = {
				file = pkgs.writeText "dyn-home.metamagical.dev.db" "";
				allowUpdate = ["127.0.0.1"];
			};
			"1.168.192.in-addr.arpa" = {
				file = pkgs.writeText "dyn-home.metamagical.dev.rev.db" "";
				allowUpdate = ["127.0.0.1"];
			};
			"w.home.metamagical.dev" = {
				file = pkgs.writeText "dyn-w.home.metamagical.dev.db" "";
				allowUpdate = ["127.0.0.1"];
			};
			"2.168.192.in-addr.arpa" = {
				file = pkgs.writeText "dyn-w.home.metamagical.dev.rev.db" "";
				allowUpdate = ["127.0.0.1"];
			};
			"block-most-private" = {
				file = pkgs.writeText "block-most-private.db" ''
					@TTL 1H
					@  SOA LOCALHOST. named-mgr.example.com    (1 1h 15m 30d 2h)
					   NS  LOCALHOST.

					8.0.0.0.127.rpz-ip CNAME .
					32.1.0.0.127.rpz-ip CNAME rpz-passthru.
				'';
				extraConfig = ''
					allow-query { none; };
				'';
			};
		};
		extraOptions = ''
			response-policy { zone block-most-private; };
		'';
	};

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
