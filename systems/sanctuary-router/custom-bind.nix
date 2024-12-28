{ config, pkgs, lib, ... }:

# based loosely on the upstream config
let 
	cfg = config.local.services.bind;

	bindPkg = config.local.services.bind.package;

	bindUser = "named";

	bindZoneOptions = { name, config, ... }: {
		options = {
			name = lib.mkOption {
				type = lib.types.str;
				default = name;
			};
			type = lib.mkOption {
				type = lib.types.enum [ "forward" "hint" "mirror" "primary" "redirect" "secondary" "static-stub" "stub"];
				default = "primary";
			};
			file = lib.mkOption {
				type = lib.types.either lib.types.str lib.types.path;
			};
			allowUpdate = lib.mkOption {
				type = lib.types.listOf lib.types.str;
				default = [];
			};
			extraConfig = lib.mkOption {
				type = lib.types.lines;
				default = "";
				description = "extra config added verbatim to the generated zone";
			};
		};
	};

	configFile = pkgs.writeText "named.conf" ''
		include "/etc/bind/rndc.key";
		controls {
			inet 127.0.0.1 allow {localhost;} keys {"rndc-key";};
		};

		options {
			listen-on { ${lib.concatMapStrings (s: " ${s}; ") cfg.listenOn };
			directory "${cfg.directory}";
			pid-file "/run/named/named.pid";

			${cfg.extraOptions}
		};

		${cfg.extraConfig}

		${lib.optionalString cfg.localhostZones ''
			zone "localhost" {
				type primary;
				notify false;
				file "${pkgs.writeText "localhost-forward.db" ''
					$TTL 3h
					localhost.  SOA      localhost.  nobody.localhost. 42  1d  12h  1w  3h
					            NS       localhost.
					            A        127.0.0.1
					            AAAA     ::1
				''}";
			};
			zone "0.0.127.in-addr.arpa" {
				type primary;
				notify false;
				file "${pkgs.writeText "localhost-reverse.db" ''
				$TTL 1D
				@        IN        SOA  localhost. root.localhost. (
				                        2007091701 ; serial
				                        30800      ; refresh
				                        7200       ; retry
				                        604800     ; expire
				                        300 )      ; minimum
				         IN        NS    localhost.
				1        IN        PTR   localhost.
				''}";
			};
		''}

		${lib.concatMapStrings
			({name, file, type, allowUpdate, extraConfig}: ''
				zone "${name}" {
					type ${type};
					file "${file}";
					${if builtins.length allowUpdate > 0 then "allow-update {${lib.concatMapStrings (s: " ${s}; ") allowUpdate}};" else ""}

					${extraConfig}
				};
			'')
			(lib.attrValues cfg.zones)
		}
	'';
in
{
	options.local.services.bind = {
		enable = lib.mkEnableOption "BIND domain name server";
		package = lib.mkPackageOption pkgs "bind" { };

		extraConfig = lib.mkOption {
			type = lib.types.lines;
			default = "";
			description = "extra config added verbatim to the generated config file";
		};
		extraOptions = lib.mkOption {
			type = lib.types.lines;
			default = "";
			description = "extra config added verbatim to the options block in the generated config file";
		};

		listenOn = lib.mkOption {
			default = [ "any" ];
			type = lib.types.listOf lib.types.str;
		};

		zones = lib.mkOption {
			default = [];
			type = lib.types.attrsOf (lib.types.submodule bindZoneOptions);
		};
		localhostZones = lib.mkOption {
			default = true;
			type = lib.types.bool;
		};

		directory = lib.mkOption {
			type = lib.types.str;
			default = "/run/named";
			description = "Working directory of BIND.";
		};
	};
	config = lib.mkIf cfg.enable {

		networking.resolvconf.useLocalResolver = lib.mkDefault true;

		users.users.${bindUser} =
			{
				group = bindUser;
				description = "BIND daemon user";
				isSystemUser = true;
			};
		users.groups.${bindUser} = {};

		systemd.services.bind = {
			description = "BIND Domain Name Server";
			after = [ "network.target" ];
			wantedBy = [ "multi-user.target" ];

			preStart = ''
				mkdir -m 0755 -p /etc/bind
				if ! [ -f "/etc/bind/rndc.key" ]; then
					${bindPkg.out}/sbin/rndc-confgen -c /etc/bind/rndc.key -u ${bindUser} -a -A hmac-sha256 2>/dev/null
				fi

				${pkgs.coreutils}/bin/mkdir -p /run/named
				chown ${bindUser} /run/named

				${pkgs.coreutils}/bin/mkdir -p ${cfg.directory}
				chown ${bindUser} ${cfg.directory}
			'';

			serviceConfig = {
				Type = "forking"; # Set type to forking, see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=900788
				ExecStart = "${bindPkg.out}/sbin/named -u ${bindUser} -c ${configFile}";
				ExecReload = "${bindPkg.out}/sbin/rndc -k '/etc/bind/rndc.key' reload";
				ExecStop = "${bindPkg.out}/sbin/rndc -k '/etc/bind/rndc.key' stop";
			};

			unitConfig.Documentation = "man:named(8)";
		};
	};
}
