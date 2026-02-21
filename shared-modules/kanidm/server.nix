{ config, lib, pkgs, ... }:

let
	cfg = config.metamagical.sso.server;
in
{
	options = with lib; {
		metamagical.sso.server = {
			enable = mkEnableOption "sso server";
			domain = mkOption {
				type = types.str;
				description = "server domain";
			};
		};
	};
	config = lib.mkIf cfg.enable {
		services.kanidm = {
			enableServer = true;
			serverSettings = {
				version = "2";

				## domain
				origin = "https://${cfg.domain}";
				domain = cfg.domain;

				## tls
				tls_key = "/var/lib/kanidm/key.pem";
				tls_chain = "/var/lib/kanidm/fullchain.pem";

				## misc
				bindaddress = "[::1]:18443";
				http_client_address_info.x-forward-for = ["::1"];
				online_backup = {
					versions = 2;
				};
			};
			package = lib.mkDefault pkgs.kanidm_1_8;
		};

		security.acme.certs."${cfg.domain}" = {
			group = "proxy-in-anger";
			domain = cfg.domain;
			dnsProvider = "porkbun";
			environmentFile = "/var/lib/secrets/acme.secret";
			postRun = ''
				cp -Lv {key,fullchain}.pem /var/lib/kanidm
				chown kanidm:kanidm /var/lib/kanidm/{key,fullchain}.pem
			'';
			reloadServices = ["kanidm.service" "proxy-in-anger.service"];
		};

		services.proxy-in-anger.domains."${cfg.domain}" = lib.mkIf config.metamagical.serving.enable {
			backends.https = [{ addr = "[::1]:18443"; skip-verifying-certs = true; }];
			tls.useACMEHost = cfg.domain;
		};
	};
}
