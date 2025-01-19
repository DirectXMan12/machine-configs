{ config, pkgs, lib, ... }:

let 
	# blocklists!
	# hagezi is overall highly reccomended (and more correct than that hosts file
	# that a lotta things shipped with), and the conclusion from some reddit
	# researcher (TODO: find link) was that light was basically just as good as
	# normal, but with slightly less risk of false positives
	hageziLight = pkgs.fetchurl {
		url = https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/domains/light.txt;
		hash = "sha256-eVHvOHTOYIlAQ6N5mLioOYDtvhl/Qkd9/ut94UcOIps=";
	};
in
	{
		router = {
			enable = true;

			dhcp.enable = true;

			dns = {
				enable = true;
				resolve = true;
				authority = "home.metamagical.dev";
				zones = {
					# add in blocklists
					"." = {
						stores = lib.mkAfter [{
							blocklist = {
								lists = [hageziLight];
							};
						}];
					};
				};
			};

			interfaces = {
				"sfp0" = {
					link.matchConfig.OriginalName = "eth1";
					type = "wan";
				};

				"sfp1" = {
					link.matchConfig.OriginalName = "eth2";
					vlans = [ "wlan-vlan" "iot-vlan" ];
					addresses = [{
						address = "192.168.1.1";
						alias = "lan";
						mask = 24;
						v4.dhcp = {
							enable = true;
							domainName = "home.metamagical.dev";
							searchPath = ["home.metamagical.dev"];
							pools = { "192.168.1.100 - 192.168.1.245" = {}; };
							dynDNS = true;
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
						};
					}];
				};

				"switch0" = {
					link.matchConfig.OriginalName = "eth0";
				};

				"wlan-vlan" = {
					vlan.id = 2;
					addresses = [{
						address = "192.168.2.1";
						alias = "wlan";
						mask = 24;
						v4.dhcp = {
							enable = true;
							domainName = "w.home.metamagical.dev";
							searchPath = ["home.metamagical.dev"];
							pools = { "192.168.2.100 - 192.168.2.245" = {}; };
							reservations = [
								# .3 was xyrithes
								# music (wlan vlan via wired)
								{ hw-address = "54:b2:03:94:0d:30"; ip-address = "192.168.2.4"; hostname = "music"; }
								{ hw-address = "d8:3a:dd:bc:04:87"; ip-address = "192.168.2.5"; hostname = "living-room-roon-bridge"; }
								# living room U7 Pro AP (on the wlan)
								{ hw-address = "28:70:4e:d5:38:83"; ip-address = "192.168.2.6"; hostname = "living-room-ap"; }
							];
						};
					}];
				};

				"iot-vlan" = {
					vlan.id = 3;
					addresses = [{
						address = "192.168.3.1";
						alias = "iot";
						mask = 24;
						v4.dhcp = {
							enable = true;
							domainName = "devices.home.metamagical.dev";
							pools = { "192.168.3.100 - 192.168.3.245" = {}; };
						};
					}];
				};
			};
		};

		# TODO: firewall ip blocklist too
	}
