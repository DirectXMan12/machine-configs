{ config, pkgs, lib, ... }:

let
	cfg = config.router;

	dhcpServerFaces = lib.attrsets.filterAttrs (name: iface: iface.type == "lan" && lib.lists.any (addr: addr.v4.dhcp.enable) iface.addresses) cfg.interfaces;
	dhcpServerFaceNames = lib.attrsets.mapAttrsToList (name: iface: name) dhcpServerFaces;

	dhcpDynDNSAddrs = let
		dynAddrsForFace = iface: lib.lists.filter (addr: addr.v4.dhcp.dynDNS) iface.addresses;
		allAddrs = lib.attrsets.mapAttrsToList (name: iface: dynAddrsForFace iface) dhcpServerFaces;
	in
		lib.lists.flatten allAddrs;
	
	hasDynDNS = builtins.length dhcpDynDNSAddrs > 0;
in
	{
		options.router.dhcp = {
			enable = lib.mkEnableOption "DHCP server";
		};

		config = with lib; {
			# TODO: reservations vs pool checks
			services.kea = mkIf cfg.dhcp.enable {
				dhcp-ddns = {
					# TODO: figure out allowing this per-client class (e.g. only static
					# mappings), which would require allowing multiple subnets with the
					# same subnet name (so allocating subnet ids or something?)
					enable = hasDynDNS;
					settings = {
						forward-ddns.ddns-domains = builtins.map (addr: {
							name = addr.v4.dhcp.domainName;
							dns-servers = [{ ip-address = "127.0.0.1"; }];
						}) dhcpDynDNSAddrs;

						reverse-ddns.ddns-domains = builtins.map (addr: {
							# TODO: ipv6 (ipv6.arpa, different split)
							name = let
								split = lib.strings.splitString "." addr.address;
								reversed = lib.lists.reverseList split;
								reversedStr = lib.strings.concatStringsSep "." reversed;
							in
								"${reversedStr}.in-addr.arpa";
							dns-servers = [{ ip-address = "127.0.0.1"; }];
						}) dhcpDynDNSAddrs;
					};
				};
				dhcp4 = {
					# TODO: configurable pool size
					enable = length dhcpServerFaceNames > 0;

					settings = {
						valid-lifetime = 7200;
						max-valid-lifetime = 86400;
						lease-database = {
							type = "memfile";
							persist = true;
							name = "/var/lib/kea/dhcp4.leases";
						};

						interfaces-config.interfaces = dhcpServerFaceNames;
						dhcp-ddns = {
							enable-updates = hasDynDNS;
						};

						subnet4 = lists.imap1 (id: subnet: subnet // { id = id; }) (lists.flatten (attrsets.mapAttrsToList (name: iface: lists.map (addr: {
							# TODO: hash iface name & address set for id?
							subnet = "${addr.address}/${toString addr.mask}";
							ddns-send-updates = addr.v4.dhcp.dynDNS;
							pools = attrsets.mapAttrsToList (pool: opts: {
								pool = pool;
							} // opts) addr.v4.dhcp.pools;
							ddns-qualifying-suffix = addr.v4.dhcp.domainName;
							option-data = [
								# TODO: allow for custom dns
								{ name = "domain-name-servers"; data = addr.address; }
							] ++ (optional (length addr.v4.dhcp.searchPath > 0) {
									name = "domain-search";
									data = lib.strings.concatStringsSep ", " addr.v4.dhcp.searchPath;
								});
							reservations = addr.v4.dhcp.reservations;
						} // addr.v4.dhcp.extraConfig) iface.addresses) dhcpServerFaces));
					};
				};
			};

		};
	}
