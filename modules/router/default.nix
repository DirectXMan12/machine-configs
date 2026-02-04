{ config, pkgs, lib, ... }:

let
	cfg = config.router;
	anyJson = (pkgs.formats.json {}).type;
	anySystemd = (pkgs.formats.systemd).lib.types.atom;

	isLink = name: iface: iface.link != null;
	toLink = name: iface: {
		"10-rename-to-${name}" = iface.link // {
			linkConfig.Name = name;
		};
	};
	isVlan = name: iface: iface.vlan.id != null;
	vlanDevName = name:
		let
			iface = cfg.interfaces."${name}";
		in
			# "vlan${toString iface.vlan.id}-${name}";
			name;
	toNetwork = name: baseIface: let
		iface = cfg.perTypeConfiguration."${baseIface.type}" // baseIface;
	in
		{
			"${if isVlan name iface then "40" else "30"}-${name}-${iface.type}" = { 
				matchConfig.Name = name;
				vlan = lib.lists.map vlanDevName iface.vlans;
				addresses = lib.lists.map (addr: {
					Address = "${addr.address}/${toString addr.mask}";
					NFTSet = "address:ip:natFirewall:host_addrs";
				}) iface.addresses;
				networkConfig = {
					# TODO: support per-type configuration properly
					DHCP = lib.mkIf (iface.type == "wan") "ipv4";
					IPv6AcceptRA = iface.type == "wan";
					IPv6SendRA = iface.type == "lan";
					DHCPPrefixDelegation = lib.mkIf (iface.type == "lan") true;
					IPv4Forwarding = true;
					IPv6Forwarding = true;
					IPMasquerade = lib.mkIf (iface.type == "wireguard") "ipv4";
				};	
				dhcpV4Config = lib.mkIf (iface.type == "wan") {
					# don't release our ip every time we change config
					SendRelease = false;
				};
				dhcpV6Config = lib.mkIf (iface.type == "wan") {
					# seems to be the max comcast will give
					# TODO: make this configurable
					PrefixDelegationHint = "::/60";
					#PrefixDelegationHint = "::/64";

					# don't release our ip every time we change config
					SendRelease = false;
				};
				# TODO: explicitly set uplink interface from wan interfaces via `UplinkInterface`?
			};
		};
	toVlan = name: iface: {
		"20-${name}-vlan" = {
			netdevConfig = {
				Kind = "vlan";
				Name = vlanDevName name;
			};
			vlanConfig.Id = iface.vlan.id;
		} // (if iface.netdev != null then iface.netdev else {});
	};
  toWgFace = name: iface: {
		# TODO: make this work
		"21-${name}-netdev" = {
			netdevConfig = {
				Kind = "wireguard";
				Name = name;
			};
		} // iface.netdev;
  };
	needsNetdev = name: iface: isVlan name iface || (iface.type == "wireguard" && iface.vlan.id == null);
	toNetdev = name: iface: if iface.vlan.id != null then
		toVlan name iface
	else
		toWgFace name iface;

	# option submodules
	interfaceOptions = { name, config, ... }: with lib; {
		options = {
			type = mkOption {
				type = types.enum ["lan" "wan" "wireguard"];
				default = "lan";
			};
			link = mkOption {
				# TODO: can we just borrow from the type definition in systemd.network?
				type = types.nullOr (types.submodule {
					options = {
						matchConfig = mkOption { type = types.attrsOf anySystemd; };
						linkConfig = mkOption { type = types.attrsOf anySystemd; };
						extraConfig = mkOption { type = types.lines; default = ""; };
					};
				});
				default = null;
			};
			vlans = mkOption {
				# TODO: check that it refers to other interfaces
				type = types.listOf types.str;
				default = [];
			};
			netdev = mkOption {
				type = types.nullOr (types.submodule {
					options = {
						netdevConfig = mkOption { type = types.nullOr (types.attrsOf anySystemd); default = null; };
						wireguardConfig = mkOption { type = types.nullOr (types.attrsOf anySystemd); default = null; };
						wireguardPeers = mkOption { type = types.nullOr (types.listOf (types.attrsOf anySystemd)); default = null; };
						# TODO: rest of the owl? i don't quite understand why attrsOf doesn't work here
						# maybe deferredModule could help?
					};
				});
				default = null;
			};
			addresses = mkOption {
				# TODO: parse address to check
				type = types.listOf (types.submodule {
					options = {
						alias = mkOption { type = types.str; };
						address = mkOption { type = types.str; };
						mask = mkOption { type = types.int; };
						v4 = {
							dhcp = {
								enable = mkEnableOption "DHCPv4 on this address";
								domainName = mkOption { type = types.str; };
								searchPath = mkOption { type = types.listOf types.str; default = []; };
								pools = mkOption { type = types.attrsOf anyJson; };
								# TODO: check that hostname is enabled if true
								dynDNS = mkOption { type = types.bool; default = false; };
								reservations = mkOption {
									type = types.listOf (types.submodule {
										options = {
											hw-address = mkOption { type = types.str; };
											ip-address = mkOption { type = types.str; };
											hostname = mkOption { type = types.nullOr types.str; default = null; };
										};
									});
									default = [];
								};
								extraConfig = mkOption {
									type = types.attrsOf anyJson;
									default = {};
								};
							};
						};
					};
				});

				default = [];
			};
			vlan = {
				id = mkOption {
					type = types.nullOr types.int;
					default = null;
				};
			};

			v4 = {
				dhcp = mkOption { type = types.bool; default = false; };
				forwarding = mkOption { type = types.bool; default = true; };
			};
			v6 = {
				acceptRA = mkOption { type = types.bool; default = false; };
				forwarding = mkOption { type = types.bool; default = true; };
			};
			# TODO: this
			requiredForOnline = mkOption {
				type = types.nullOr types.str;
				default = null;
			};
		};
	};

in
	{
		imports = [
			./dhcp.nix
			./dns.nix
			./firewall.nix
		];
		options.router = with lib; {
			enable = mkEnableOption "router functionality";
			perTypeConfiguration = {
				 # TODO: custom iface types
				 # TODO: make this... more generic
				 wan = mkOption {
					type = types.submodule {
						options = {
							v4 = {
								dhcp = mkOption { type = types.bool; default = true; };
								forwarding = mkOption { type = types.bool; default = true; };
							};
							v6 = {
								acceptRA = mkOption { type = types.bool; default = true; };
								forwarding = mkOption { type = types.bool; default = true; };
							};
							# TODO: this
							requiredForOnline = mkOption {
								type = types.nullOr types.str;
								default = null;
							};
						};
					};

					default = {
						v4 = {
							dhcp = true;
							forwarding = true;
						};
						v6 = {
							acceptRA = true;
							forwarding = true;
						};
					};
				};
				# TODO: this
				lan = mkOption {
					type = types.submodule {
						options = {
							requiredForOnline = mkOption {
								type = types.nullOr types.str;
								default = null;
							};
						};
					};
					default = {};
				};
				wireguard = mkOption {
					type = types.submodule {
						options = {
							requiredForOnline = mkOption {
								type = types.nullOr types.str;
								default = null;
							};
						};
					};
					default = {};
				};
			};
			interfaces = mkOption {
				type = types.attrsOf (types.submodule interfaceOptions);
				default = {};
			};
		};
		config = lib.mkIf cfg.enable (with lib; {
			systemd.network = {
				enable = true;

				links = let
					linkFaces = attrsets.filterAttrs isLink cfg.interfaces;
				in attrsets.concatMapAttrs toLink linkFaces;

				config.networkConfig = {
					# :screaming-internally: ipv6 forwarding must be turned on at the
					# system level in order for the per-network setting to have any
					# effect (unlike ipv4, which doesn't need this) idk why the
					# per-network setting doesn't imply the global setting in that case.
					IPv6Forwarding = true;
				};

				networks = attrsets.concatMapAttrs toNetwork cfg.interfaces;
				
				netdevs = let
					faces = attrsets.filterAttrs needsNetdev cfg.interfaces;
				in 
					attrsets.concatMapAttrs toNetdev faces;
			};

			# TODO: dns

			networking = {
				# configured above per-interface
				useDHCP = false;

				# we'll configure our own
				nat.enable = false;
				firewall.enable = false;
			};
		});
	}

	# TODO: avahi
