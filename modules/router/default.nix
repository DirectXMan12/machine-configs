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
			"vlan${toString iface.vlan.id}-${name}";
	toNetwork = name: baseIface: let
		iface = cfg.perTypeConfiguration."${baseIface.type}" // baseIface;
	in
		iface.network // {
			"${if isVlan name iface then "40" else "30"}-${name}-${iface.type}" = { 
				matchConfig.Name = name;
				vlan = lib.lists.map vlanDevName iface.vlans;
				address = lib.lists.map (addr: addr.address) iface.addresses;
			};
		};
	toVlan = name: iface: {
		"20-${name}-vlan" = {
			netdevConfig = {
				Kind = "vlan";
				Name = vlanDevName name;
			};
			vlanConfig.Id = iface.vlan.id;
		};
	};

	# option submodules
	interfaceOptions = { name, config, ... }: with lib; {
		options = {
			type = mkOption {
				type = types.enum ["lan" "wan"];
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
			network = mkOption {
				type = types.submodule {
					options = {};
				};
				default = {};
			};
			vlans = mkOption {
				# TODO: check that it refers to other interfaces
				type = types.listOf types.str;
				default = [];
			};
			addresses = mkOption {
				# TODO: parse address to check
				type = types.listOf (types.submodule {
					options = {
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

in
	{
		imports = [
			./dhcp.nix
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

				networks = attrsets.concatMapAttrs toNetwork cfg.interfaces;
				
				# TODO: other netdev support
				netdevs = let
					vlanFaces = attrsets.filterAttrs isVlan cfg.interfaces;
				in 
					attrsets.concatMapAttrs toVlan vlanFaces;
			};

			# TODO: dns

			networking = {
				# configured above per-interface
				useDHCP = false;

				# we'll configure our own
				nat.enable = false;
				firewall.enable = false;

				nftables = {
					enable = true;
				};
			};
		});
	}
