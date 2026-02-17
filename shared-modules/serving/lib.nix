{ lib, ... }:

with lib; rec {
	http-backend = types.submodule {
		options = {
			addr = mkOption { type = types.str; };
			weight = mkOption { type = types.nullOr types.int;	default = null; };
			ca-path = mkOption { type = types.nullOr types.str; default = null; };
			skip-verifying-certs = mkOption { type = types.bool; default = false; };
		};
	};
	uds-backend = types.submodule {
		options = {
			path = mkOption { type = types.str; };
			weight = mkOption { type = types.nullOr types.int;	default = null; };
		};
	};
	claim-cfg = types.submodule {
		options = {
			header = mkOption { type = types.str; };
			serialize-as = mkOption { type = types.nullOr (types.submodule {
				options = {
					join-keys-and-values-with = mkOption { type = types.nullOr types.str; default = null; };
					join-key-value-pairs-with = mkOption { type = types.nullOr types.str; default = null; };
					join-array-items-with = mkOption { type = types.nullOr types.str; default = null; };
				};
			}); default = null; };
		};
	};
	claims-cfg = types.submodule {
		options = {
			claims-to-headers = mkOption { type = types.nullOr (types.attrsOf claim-cfg); default = null; };
		};
	};
	scopes-cfg = types.submodule {
		options = {
			required = mkOption { type = types.listOf types.str;	default = []; };
		};
	};
	oidc-cfg = types.submodule {
		options = {
			discovery-url-base = mkOption { type = types.str; };
			client-id = mkOption { type = types.str; };
			client-secret-path = mkOption { type = types.str; };
			logout-url = mkOption { type = types.str; };
			scopes = mkOption { type = types.nullOr scopes-cfg; default = null; };
			claims = mkOption { type = types.nullOr claims-cfg; default = null; };

			extraConfig = mkOption { type = types.lines; default = ""; };
		};
	};
	headers-cfg = types.submodule {
		options = {
			host = mkOption { type = types.nullOr types.str; default = null; };
			x-forwarded-for = mkOption { type = types.nullOr types.str; default = null; };
			x-forwarded-proto = mkOption { type = types.nullOr types.str; default = null; };
			remote-addr = mkOption { type = types.listOf types.str; default = []; };
			always-clear = mkOption { type = types.listOf types.str; default = []; };
		};
	};
	tls-cfg = types.submodule {
		options = {
			cert-path = mkOption { type = types.str; };
			key-path = mkOption { type = types.str; };
			useACMEHost = mkOption {
				type = types.str;
				description = "use the given acme host for certs instead of manually specifying them (overrides cert-path and key-path)";
			};
		};
	};
	domain-cfg = types.submodule {
		options = {
			backends = {
				http = mkOption {
					type = types.listOf http-backend;
					default = [];
				};
				https = mkOption {
					type = types.listOf http-backend;
					default = [];
				};
				uds = mkOption {
					type = types.listOf uds-backend;
					default = [];
				};
			};
			oidc-auth = mkOption {
				type = types.nullOr oidc-cfg;
				default = null;
			};
			manage-headers = mkOption {
				type = types.nullOr headers-cfg;
				default = null;
			};
			tls = mkOption {
				type = types.nullOr tls-cfg;
				default = null;
			};
			extraConfig = mkOption {
				type = types.lines;
				default = "";
			};
		};
	};
}
