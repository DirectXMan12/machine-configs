{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
	#### auth
	metamagical.sso.server = {
		enable = true;
		domain = "sso.metamagical.house";
	};
	services.kanidm = {
		serverSettings.online_backup = {
			path = "/service-backups/kanidm/";
		};
	};
	networking.firewall.allowedTCPPorts = [
		# for sso
		28443
	];

	#### set sso.metamagical.house externally
	services.oink = {
		enable = true;
		# ipv4 is set on the router since we're using nat
		domains = [
			{ domain = "metamagical.house"; subdomain = "sso"; skipIPv4 = true; }
			# ipv4 is handled on the router, everything else is a cname
			{ domain = "metamagical.house"; subdomain = "services"; skipIPv4 = true; }
			# root domain, can't cname (effectively, waves hands, per dns spec)
			{ domain = "metamagical.house"; subdomain = ""; skipIPv4 = true; }
		];
		apiKeyFile = "/etc/keys/oink.key";
		secretApiKeyFile = "/etc/keys/oink.secret-key";
	};

	#### internal/external site hosting
	metamagical.serving = {
		enable = true;
		static-sites = let
			oidc-cfg = client: scopes: {
				discovery-url-base = "https://sso.metamagical.house/oauth2/openid/${client}/";
				client-id = client;
				logout-url = "https://sso.metamagical.house";
				client-secret-path = "/var/lib/secrets/${client}.client-secret";
				scopes.required = scopes;
			};
			headers = {
				x-forwarded-for = "x-forwarded-for";
				x-forwarded-proto = "x-forwarded-proto";
			};
			internal-hosted = client: {
				oidc-auth = oidc-cfg client ["view"];
				manage-headers = headers;
				tls.useACMEHost = "home.metamagical.dev";
			};
			external-hosted = { client, acme ? "${client}.metamagical.house" }: {
				oidc-auth = oidc-cfg client ["view"];
				manage-headers = headers;
				tls.useACMEHost = acme;
			};
		in
			{
				"5etools.house.metamagical.dev" = {
					root = "/web-root/5etools";
					proxy-config = internal-hosted "five-e-tools";
				};
				"metamagical.house" = {
					root = "/web-root/house";
					proxy-config = external-hosted { client = "main-site"; acme = "metamagical.house"; };
				};
				"www.metamagical.house" = {
					redirect = {
						from = "/{*}";
						to = "https://metamagical.house/$1";
						code = 301;
					};
					# this is intentionally public since it's just a redirect
					proxy-config = { manage-headers = headers; tls.useACMEHost = "metamagical.house"; };
				};
			};
	};
	services.proxy-in-anger = {
		# internal serving for kanidm (legacy reasons)
		bind-to.tcp = lib.mkAfter [{ addr = "[::]:28443"; }];
		domains = {
			"kavita.metamagical.house" = {
				backends.http = [{ addr = "127.0.0.1:65004"; }];
				tls.useACMEHost = "kavita.metamagical.house";
				# does its own oidc
				manage-headers = {
					# set, not append
					remote-addr = [ "x-forwarded-for" ];
					x-forwarded-proto = "x-forwarded-proto";
					always-clear = [ "x-real-ip" ];
				};
			};
			"home.metamagical.house" = {
				backends.http = [{ addr = "[::1]:8123"; }];
				tls.useACMEHost = "home.metamagical.house";
				manage-headers = {
					x-forwarded-for = "x-forwarded-for";
					x-forwarded-proto = "x-forwarded-proto";
				};
				# does its own oidc
			};
		};
	};
	security.acme = {
		acceptTerms = true;
		defaults.email = "directxman12+acme@metamagical.dev";
		certs = {
			"home.metamagical.dev" = {
				group = "proxy-in-anger";
				domain = "*.home.metamagical.dev";
				dnsProvider = "porkbun";
				environmentFile = "/var/lib/secrets/acme.secret";
				extraDomainNames = [ "*.house.metamagical.dev" "house.metamagical.dev" "home.metamagical.dev" "plex.metamagical.dev" ];
				# TODO: this is needed because internal dns returns a SOA record for home.metamagical.dev
				# (correctly), but when acme-go tries to split the domain it thinks that means it should try for
				# `name = *, domain = home.metamagical.dev`, not `name = *.home, domain = metamagical.dev`.
				dnsResolver = "8.8.8.8:53";
			};

			"kavita.metamagical.house" = {
				group = "proxy-in-anger";
				domain = "kavita.metamagical.house";
				dnsProvider = "porkbun";
				environmentFile = "/var/lib/secrets/acme.secret";
				reloadServices = ["proxy-in-anger.service"];
			};

			"home.metamagical.house" = {
				group = "proxy-in-anger";
				domain = "home.metamagical.house";
				dnsProvider = "porkbun";
				environmentFile = "/var/lib/secrets/acme.secret";
				reloadServices = ["proxy-in-anger.service"];
			};

			"metamagical.house" = {
				group = "proxy-in-anger";
				domain = "metamagical.house";
				dnsProvider = "porkbun";
				extraDomainNames = [ "www.metamagical.house" ];
				environmentFile = "/var/lib/secrets/acme.secret";
				reloadServices = ["proxy-in-anger.service"];
			};

			# TODO: this is needed because internal dns returns a SOA record for home.metamagical.dev
			# (correctly), but when acme-go tries to split the domain it thinks that means it should try for
			# `name = *, domain = home.metamagical.dev`, not `name = *.home, domain = metamagical.dev`.
			"sso.metamagical.house".dnsResolver = "8.8.8.8:53";
		};
	};

	###### copyparty, for managing afh music uploads and kavita
	metamagical.copyparty = {
		enable = true;
		domain = "files.metamagical.house";
		volumes = {
			"/music" = {
				dir = "/roon-music/roon-music/local-stuff";
				extraConfig = ''
				accs:
					rw: directxman12, @uploader
				'';
			};
			"/books" = {
				dir = "/books";
				extraConfig = ''
				accs:
					rw: directxman12, @uploader
				'';
			};
			"/dont-copy-this-floppy" = {
				dir = "/web-root/house/dont-copy-this-floppy";
				extraConfig = ''
				accs:
					r: @viewer
					w: directxman12, @floppysender
				'';
			};
		};
		globalConfig = ''
		# indexing
		e2dsa
		# allow seeing dotfiles
		ed
		'';
	};

	###### kavita (calibre-like, but with better support for manga)
	services.kavita = {
		package = pkgs.callPackage ./kavita.nix {};
		enable = true;
		user = "calibre";
		settings = {
			Port = 65004;
			IpAddresses = "127.0.0.1";
			OpenIdConnectSettings = {
				Authority = "https://sso.metamagical.house/oauth2/openid/kavita";
				ClientId = "kavita";
				Secret = "@OIDC_SECRET@";
			};
		};
		dataDir = "/web-root/kavita";
		tokenKeyFile = "/web-root/kavita/tokens.key";
	};
	# till this gets resolved upstream
	systemd.services.kavita = {
		after = ["kanidm.service"]; # needs to autodetect working openid url
		preStart = lib.mkAfter
			''
				${pkgs.replace-secret}/bin/replace-secret '@OIDC_SECRET@' ''${CREDENTIALS_DIRECTORY}/oidc_secret /web-root/kavita/config/appsettings.json
			'';
		serviceConfig.LoadCredential = lib.mkAfter [ "oidc_secret:/web-root/kavita/oidc-secret.key" ];
	};

	users.users = {
		calibre = {
			isSystemUser = true;
			group = "calibre";
		};
	};

	users.groups = {
		calibre = {
			members = ["calibre"];
		};
	};
}
