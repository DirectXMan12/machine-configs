{ config, pkgs, lib, ... }:

{
	imports = [
		./hardware.nix
	];

	#### roon & plex
	nixpkgs.overlays = lib.mkAfter [
		(pkgfinal: pkgprev: {
			roon-server = pkgprev.roon-server.overrideAttrs (final: prev: {
				version = "2.59.1625";
				urlVersion = builtins.replaceStrings [ "." ] [ "0" ] final.version;
				src = pkgs.fetchurl {
					url = "https://download.roonlabs.com/updates/earlyaccess/RoonServer_linuxx64_${final.urlVersion}.tar.bz2";
					hash = "sha256-UbGe6XLezBO3ugiN5gSHQCyUCM6BHur40FO9M7Ris3s=";
				};
			});
		})
	];

	users.users = {
		roon-server = {
			isSystemUser = true;
			uid = 997; # for a stable uid for /roon-music mount
		};
		calibre = {
			isSystemUser = true;
			group = "calibre";
		};
	};

	users.groups = {
		music-players = {
			members = [ "roon-server" "plex" ];
			gid = 993; # stable gid for /roon-music mount
		};
		calibre = {
			members = ["calibre"];
		};
	};

	environment.systemPackages = lib.mkAfter (with pkgs; [
		# roon
		ffmpeg
		cifs-utils
	]);

	allowedUnfree = lib.mkAfter [
		"roon-server"
		"plexmediaserver"
		# temporary
		"unifi-controller"
		"mongodb-ce"
	];

	services.roon-server = {
		enable = true;
		openFirewall = true;
		user = "roon-server"; # explict to match up with stable-uid stuff above
	};

	services.plex = {
		enable = true;
		openFirewall = true;
		package = pkgs.plex.overrideAttrs (final: old: {
			version = "1.41.0.8994-f2c27da23";
			src = pkgs.fetchurl {
				url = "https://downloads.plex.tv/plex-media-server-new/${final.version}/debian/plexmediaserver_${final.version}_amd64.deb";
				sha256 = "sha256-e1COeawdR0pCF+qQ/xkTn/716iM9kB/fXom5MWHQ0YI=";
			};
		});
	};

	services.unifi = {
		enable = true;
		openFirewall = true;
		unifiPackage = pkgs.unstable.unifi;
		mongodbPackage = pkgs.mongodb-ce;
	};

	# Open ports in the firewall.
	networking.firewall.allowedTCPPorts = [
		# roon arc
		55000

		# unifi controller web
		8443

		# unifi remote management
		5349

		# for sso
		28443
	];
	networking.firewall.allowedUDPPorts = [
		# roon arc
		55000
	];
	networking.firewall.checkReversePath = "loose"; # weird dual nic setup

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

	#### set sso.metamagical.house externally
	services.oink = {
		enable = true;
		# ipv4 is set on the router since we're using nat
		domains = [
			{ domain = "metamagical.house"; subdomain = "sso"; skipIPv4 = true; }
			# ipv4 is handled on the router, everything else is a cname
			{ domain = "metamagical.house"; subdomain = "services"; skipIPv4 = true; }
		];
		apiKeyFile = "/etc/keys/oink.key";
		secretApiKeyFile = "/etc/keys/oink.secret-key";
	};

	#### internal site hosting
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
			generic-hosted = client: {
				oidc-auth = oidc-cfg client ["view"];
				manage-headers = headers;
				tls.useACMEHost = "home.metamagical.dev";
			};
		in
			{
				"5etools.house.metamagical.dev" = {
					root = "/web-root/5etools";
					proxy-config = generic-hosted "five-e-tools";
				};
				"house.metamagical.dev" = {
					root = "/web-root/house";
					proxy-config = generic-hosted "main-site";
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
		package = pkgs.unstable.kavita;
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

	### networking setup
	systemd.network = {
		networks = {
			"30-wired-lan" = {
				matchConfig.Name = "eno1";
				vlan = [ "wlan-vlan" ];
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
			};
			"40-wlan-vlan" = {
				matchConfig.Name = "wlan-vlan";
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
			};
		};

		# join to the wlan vlan for roon stuff, since roon can't discover cross-vlan
		netdevs = {
			"20-wlan-vlan-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "wlan-vlan";
				};
				vlanConfig.Id = 2;
			};
		};
		# use stable ipv6 addresses only (part 1)
		config.networkConfig.IPv6PrivacyExtensions = false;	
	};

	# use stable ipv6 addresses only (part 2)
	networking.tempAddresses = "disabled";

	# only on the specified adapters
	networking.useDHCP = false;
	networking.nftables.enable = true;


	# This option defines the first version of NixOS you have installed on this particular machine,
	# and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
	#
	# Most users should NEVER change this value after the initial install, for any reason,
	# even if you've upgraded your system to a new NixOS release.
	#
	# This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
	# so changing it will NOT upgrade your system.
	#
	# This value being lower than the current NixOS release does NOT mean your system is
	# out of date, out of support, or vulnerable.
	#
	# Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
	# and migrated your data accordingly.
	#
	# For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
	system.stateVersion = "23.11"; # Did you read the comment?
}
