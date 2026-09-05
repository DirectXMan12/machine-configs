{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
	disabledModules = [ "services/home-automation/matter-server.nix" "services/home-automation/home-assistant.nix" ];
	imports = [
		./hardware.nix
		"${nixpkgs-unstable}/nixos/modules/services/home-automation/matterjs-server.nix"
		"${nixpkgs-unstable}/nixos/modules/services/home-automation/home-assistant.nix"
	];

	#### roon & plex
	nixpkgs.overlays = lib.mkAfter [
		(pkgfinal: pkgprev: {
			roon-server = pkgprev.roon-server.overrideAttrs (final: prev: {
				version = "2.71.1684";
				urlVersion = builtins.replaceStrings [ "." ] [ "0" ] final.version;
				src = pkgs.fetchurl {
					url = "https://download.roonlabs.com/updates/earlyaccess/RoonServer_linuxx64_${final.urlVersion}.tar.bz2";
					hash = "sha256-6nDDpsouWqaYGKp3Tn2bFaw3UnkefFoIvMiy38t4LEQ=";
				};

				installPhase =
					let 
						wrapBin = binPath: ''
							(
								binDir="$(dirname "${binPath}")"
								binName="$(basename "${binPath}")"
								actualBin="$binDir/$binName.exe"

								rm "${binPath}"
								makeWrapper "$actualBin" "${binPath}" \
									--argv0 "$binName" \
									--prefix LD_LIBRARY_PATH : "${
										lib.makeLibraryPath (with pkgs; [
											alsa-lib
											icu66
											ffmpeg
											openssl
										])
									}" \
									--prefix PATH : "$binDir" \
									--prefix PATH : "${
										lib.makeBinPath (with pkgs; [
											alsa-utils
											cifs-utils
											ffmpeg
										])
									}" \
									--chdir "$binDir"
							)

						'';
					in
						''
							runHook preInstall
							mkdir -p $out
							mv * $out
							rm $out/check.sh
							rm $out/start.sh
							rm $out/VERSION

							${wrapBin "$out/Appliance/RAATServer"}
							${wrapBin "$out/Appliance/RoonAppliance"}
							${wrapBin "$out/Server/RoonServer"}

							mkdir -p $out/bin
							makeWrapper "$out/Server/RoonServer" "$out/bin/RoonServer" --chdir "$out"

							runHook postInstall
						'';
					
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
		jrePackage = pkgs.jdk25_headless; # newer unifis need this, will be default in nixos 26.05
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
				"house.metamagical.dev" = {
					# violate beyondcorp principles a bit, and just expose this plain internally
					root = "/web-root/house";
					proxy-config = { manage-headers = headers; tls.useACMEHost = "home.metamagical.dev"; };
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

	###### home-assistant
	services.home-assistant = {
		enable = true;
		package = pkgs.unstable.home-assistant;
		extraComponents = [
			# required for onboarding
			"analytics"
			"google_translate"
			"met"
			"radio_browser"
			"shopping_list"

			# zlib compression
			"isal"

			# matter
			"matter"
			"otbr"

			# misc
			"google_weather"
		];
		customComponents = with pkgs.unstable.home-assistant-custom-components; [
			auth_oidc
		];
		config = {
			"automation ui" = "!include automations.yaml";
			"scene ui" = "!include scenes.yaml";
			"script ui" = "!include scripts.yaml";
			default_config = {};
			http = {
				server_host = "::1";
				trusted_proxies = [ "::1" ];
				use_x_forwarded_for = true;
			};
			auth_oidc = {
				client_id = "home-assistant";
				discovery_url = "https://sso.metamagical.house/oauth2/openid/home-assistant/.well-known/openid-configuration";
				features.automatic_person_creation = true;
				id_token_signing_alg = "ES256";
				roles = {
					admin = "home-admins@sso.metamagical.house";
					user = "home-users@sso.metamagical.house";
				};
			};
		};
	};
	systemd.tmpfiles.rules = [
		"f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass"
	];

	services.matterjs-server = {
		enable = true;
		package = pkgs.unstable.matterjs-server;
		extraArgs = ["--vendorid=4939"];
	};


	### networking setup
	systemd.network = {
		networks = {
			"30-wired-lan" = {
				matchConfig.Name = "eno1";
				vlan = [ "wlan-vlan" "lan-vlan" ];
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
			"41-lan-vlan" = {
				matchConfig.Name = "lan-vlan";
				networkConfig = {
					DHCP = "ipv4";
					IPv6AcceptRA = true;
				};
				dhcpV4Config = {
					ClientIdentifier = "mac";
				};
				routes = [{
					# ip route add fd2f:fb3a:f99a:1::/64 nexthop via fe80::4073:e7ff:fe87:6614 dev lan-vlan
					Destination = "fd2f:fb3a:f99a:1::/64";
					Gateway = "fe80::4073:e7ff:fe87:6614";
				}];
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
			"21-lan-vlan-vlan" = {
				netdevConfig = {
					Kind = "vlan";
					Name = "lan-vlan";
				};
				vlanConfig.Id = 1;
			};
		};
		# use stable ipv6 addresses only (part 1)
		config.networkConfig.IPv6PrivacyExtensions = false;	
	};

	# screws up matter royally to have this on
	services.resolved.settings.Resolve.MulticastDNS = false;

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
