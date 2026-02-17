{ pkgs, config, lib, ... }:

let
	cfg = config.metamagical.copyparty;
	auth-server = config.metamagical.sso.pam.server;
in
{
	options = with lib; {
		metamagical.copyparty = {
			enable = mkEnableOption "copyparty file server";
			domain = mkOption {
				type = types.str;
				description = "domain where copyparty will be served";
			};
			volumes = mkOption {
				type = types.attrsOf (types.submodule {
					options = {
						dir = mkOption {
							type = types.either types.path types.str;
							default = "";
							description = "real directory on the filesystem to serve";
						};
						extraConfig = mkOption {
							type = types.lines;
							default = "";
						};
					};
				});
			};
			globalConfig = mkOption {
				type = types.lines;
				default = "";
			};
			extraConfig = mkOption {
				type = types.lines;
				default = "";
			};
		};
	};
	config = lib.mkIf cfg.enable {
		systemd.services.copyparty = {
			name = "copyparty.service";
			description = "copyparty!";
			wantedBy = [ "multi-user.target" ];
			after = [ "network.target" "kanidm.service" ];
			serviceConfig = {
				# be paranoid
				CapabilityBoundingSet = [];
				DeviceAllow = "";
				LockPersonality = true;
				PrivateDevices = true;
				PrivateMounts = true;
				PrivateUsers = false;
				PrivateGroups = false;
				PrivateTmp = true;
				ProcSubset = "pid";
				ProtectClock = true;
				ProtectHome = true;
				ProtectHostname = true;
				ProtectControlGroups = true;
				ProtectKernelLogs = true;
				ProtectKernelModules = true;
				ProtectKernelTunables = true;
				ProtectProc = "invisible";
				RestrictAddressFamilies = [ "AF_UNIX" ];
				RestrictNamespaces = true;
				RestrictRealtime = true;
				RestrictSUIDSGID = true;
				SystemCallArchitectures = "native";
				# TODO: something here blocks copyparty from working
				# SystemCallFilter = [
				#   "@system-service"
				#   "~@privileged @resources @setuid @keyring"
				# ];
				TemporaryFileSystem = "/:ro";
				# allow some stuff
				BindPaths = lib.mapAttrsToList (_name: vol: vol.dir) cfg.volumes;
				BindReadOnlyPaths = [
					# copyparty itself
					"/nix/store"
					# to get the group name
					"/etc/group"
				];
				# general settings
				ExecStart = let
						configFile = pkgs.writeText "copyparty.cfg" ''
						[global]
						${cfg.globalConfig}
						${lib.optionalString config.metamagical.serving.enable ''
						# auth proxy will inject these
						idp-h-usr: x-idp-user
						idp-h-grp: x-idp-groups
						idp-gsep: ,
						${lib.optionalString (config.metamagical.sso.pam ? server) "idp-login: ${config.metamagical.sso.pam.server}"}
						${lib.optionalString (config.metamagical.sso.pam ? server) "idp-logout: ${config.metamagical.sso.pam.server}/.oauth2/logout"}
						xff-hdr: x-forwarded-for
						rproxy: -1
						''}

						hist: /var/lib/copyparty/hist

						i: unix:770:copyparty-connect:/run/copyparty/party.sock


						${cfg.extraConfig}

						${lib.concatStrings (lib.mapAttrsToList (name: vol: ''
							[${name}]
								${vol.dir}
								${vol.extraConfig}
						'') cfg.volumes)}
						'';
					in
					"${pkgs.copyparty}/bin/copyparty -c ${configFile}";
				User = "copyparty";
				Group = "copyparty";
				RuntimeDirectory = "copyparty";
				StateDirectory = "copyparty";
			};
			environment = {
				# it wants to store state in the config dir???
				XDG_CONFIG_HOME = "/var/lib/copyparty";
			};
		};

		users.users.copyparty = {
			isSystemUser = true;
			group = "copyparty";
		};
		users.groups.copyparty = {
			members = ["copyparty"];
		};
		users.groups.copyparty-connect = lib.mkIf config.metamagical.serving.enable {
			# ideally systemd would create the socket and pass it in but copyparty
			# isn't set up for that
			members = ["copyparty" "proxy-in-anger"];
		};

		services.proxy-in-anger.domains."${cfg.domain}" = lib.mkIf config.metamagical.serving.enable {
			backends.uds = [{ path = "/run/copyparty/party.sock"; }];
			tls.useACMEHost = cfg.domain;

			manage-headers = {
				x-forwarded-for = "x-forwarded-for";
				x-forwarded-proto = "x-forwarded-proto";
			};

			oidc-auth = {
				discovery-url-base = "${auth-server}/oauth2/openid/copyparty/";
				client-id = "copyparty";
				logout-url = auth-server;
				client-secret-path = "/var/lib/secrets/copyparty.client-secret";
				scopes.required = ["profile" "viewer"];
				claims.claims-to-headers = {
					"scopes" = { header = "x-idp-groups"; serialize-as.join-array-items-with = ","; };
					"preferred_username" = { header = "x-idp-user"; };
				};
			};
		};
		security.acme.certs."${cfg.domain}" = lib.mkIf config.metamagical.serving.enable {
			group = "proxy-in-anger";
			domain = cfg.domain;
			dnsProvider = "porkbun";
			environmentFile = "/var/lib/secrets/acme.secret";
			reloadServices = ["proxy-in-anger.service"];
		};
	};
}

