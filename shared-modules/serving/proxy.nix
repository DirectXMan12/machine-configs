{ config, lib, pkgs, ... }:

let
	cfg = config.services.proxy-in-anger;
	proxy-lib = import ./lib.nix { inherit lib; };
in
{
	options = with lib; {
		services.proxy-in-anger = {
			enable = mkEnableOption "proxy-in-anger";
			package = mkPackageOption pkgs "proxy-in-anger" {};

			domains = mkOption {
				type = types.attrsOf proxy-lib.domain-cfg;
				default = [];
			};

			bind-to = {
				tcp = mkOption {
					type = types.listOf (types.submodule {
						options = {
							addr = mkOption { type = types.str; };
						};
					});
				};
			};

			extraConfig = mkOption {
				type = types.lines;
				default = "";
			};
		};
	};

	config = lib.mkMerge [
		(lib.mkIf config.metamagical.serving.enable {
			services.proxy-in-anger = {
				enable = true;
				bind-to.tcp = [
					{ addr = "[::]:443"; }
				];

				# TODO: put socket and pid file in the run directory
				extraConfig = ''
					pingora {
						# the default is 300 (5 minutes)??? so looong
						grace_period_seconds: 5
					}
				'';
			};

			networking.firewall.allowedTCPPorts = lib.mkAfter [
				443
			];
		})
		(lib.mkIf cfg.enable {
			systemd.services.proxy-in-anger = {
				wantedBy = [ "multi-user.target" ];
				serviceConfig =
					let
						scalar = name: val: "${name}: ${val}";
						scalarOpt = name: val: lib.optionalString (val != null) (scalar name val);
						scalarStr = name: val: "${name}: \"${val}\"";
						scalarStrOpt = name: val: lib.optionalString (val != null) (scalarStr name val);
						blockOpt = name: val: do: lib.optionalString (val != null) ''
						${name} {
							${do val}
						}
						'';
						configPath = pkgs.writeText "proxy-in-anger.textproto" ''
							${lib.concatMapStrings (bind: blockOpt "bind_to_tcp" bind (cfg: ''
								${scalarStr "addr" cfg.addr}
							'')) cfg.bind-to.tcp}

							${lib.concatStrings (lib.mapAttrsToList (name: cfg: ''
								domains {
									key: "${name}"
									value {
										${blockOpt "tls" cfg.tls (cfg: ''
											${if (cfg ? useACMEHost) then (
													let
														cert-dir = config.security.acme.certs.${cfg.useACMEHost}.directory;
													in ''
														${scalarStr "cert_path" "${cert-dir}/fullchain.pem"}
														${scalarStr "key_path" "${cert-dir}/key.pem"}
													''
												) else ''
													${scalarStr "cert_path" cfg.cert-path}
													${scalarStr "key_path" cfg.key-path}
												''
											}
										'')}

										${lib.concatMapStrings (cfg: ''
											http {
												${scalarStr "addr" cfg.addr}
												${scalarOpt "weight" cfg.weight}
											}
										'') cfg.backends.http }

										${lib.concatMapStrings (cfg: ''
											https {
												${scalarStr "addr" cfg.addr}
												${scalarOpt "weight" cfg.weight}
												${scalarStrOpt "ca_path" cfg.ca-path}
												${scalar "skip_verifying_certs" (lib.boolToString cfg.skip-verifying-certs)}
											}
										'') cfg.backends.https }
										${lib.concatMapStrings (cfg: ''
											uds {
												${scalarStr "path" cfg.path}
												${scalarOpt "weight" cfg.weight}
											}
										'') cfg.backends.uds }

										${blockOpt "oidc_auth" cfg.oidc-auth (cfg: ''
											${scalarStr "discovery_url_base" cfg.discovery-url-base}
											${scalarStr "client_id" cfg.client-id}
											${scalarStr "client_secret_path" cfg.client-secret-path}
											${scalarStr "logout_url" cfg.logout-url}

											${blockOpt "scopes" cfg.scopes (cfg: ''
												${lib.concatMapStringsSep "\n" (req: scalarStr "required" req) cfg.required}
											'')}

											${blockOpt "claims" cfg.claims (cfg: ''
												${lib.concatStrings (lib.mapAttrsToList (claim: header: ''
													claim_to_header {
														${scalarStr "claim" claim}
														${scalarStr "header" header.header}
														${blockOpt "serialize_as" header.serialize-as (ser: ''
															${scalarStrOpt	"join_keys_and_values_with" ser.join-keys-and-values-with}
															${scalarStrOpt "join_key_value_pairs_with" ser.join-key-value-pairs-with}
															${scalarStrOpt "join_array_items_with" ser.join-array-items-with}
														'')}
													}
												'') cfg.claims-to-headers)}
											'')}
										'')}

										${blockOpt "manage_headers" cfg.manage-headers (cfg: ''
											${scalarStrOpt "host" cfg.host}
											${scalarStrOpt "x_forwarded_for" cfg.x-forwarded-for}
											${scalarStrOpt "x_forwarded_proto" cfg.x-forwarded-proto}
											${lib.concatMapStringsSep "\n" (a: scalarStr "remote_addr" a) cfg.remote-addr}
											${lib.concatMapStringsSep "\n" (h: scalarStr "always_clear" h) cfg.always-clear}
										'')}

										${cfg.extraConfig}
									}
								}
							'') cfg.domains)}

							${cfg.extraConfig}
						'';
					in
					{
						ExecStart = ["${lib.getExe cfg.package} -c ${configPath}"];
						User = "proxy-in-anger";
						Group = "proxy-in-anger";
						StateDirectory = "proxy-in-anger";
						Restart = "on-failure";
						RestartSec = "5s";
						AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];

						NoNewPrivileges = true;
						PrivateDevices = true;
						ProtectHome = true;
					};
			};

			# TODO: use runLocalCommand to validate config

			users.users.proxy-in-anger = {
				isSystemUser = true;
				group = "proxy-in-anger";
				home = "/var/lib/proxy-in-anger";
			};
			users.groups.proxy-in-anger = {};
		})
	];
}
