{ config, pkgs, lib, ... }:

{
	imports = [
		./hardware.nix
	];

	#### roon & plex
	nixpkgs.overlays = lib.mkAfter [
		(pkgfinal: pkgprev: {
			roon-server = pkgprev.roon-server.overrideAttrs (final: prev: {
				version = "2.58.1605";
				urlVersion = builtins.replaceStrings [ "." ] [ "0" ] final.version;
				src = pkgs.fetchurl {
					url = "https://download.roonlabs.com/updates/earlyaccess/RoonServer_linuxx64_${final.urlVersion}.tar.bz2";
					hash = "sha256-VoimaTP7N8cFHgtXO1N1C1J1voEAlRohJlH6LkK71kA=";
				};
			});
		})
	];

	users.users = {
		directxman12.openssh.authorizedKeys.keys = lib.mkAfter [
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCuxQ7uqalsYZtY5Srp6/bDBaYakzrdcoIHBCFHkD61qjBMsP7UuFQRZ93rOmQVKHFZQvmO3/cep5eLOwmOLeSdEmAXam1XN4CCbRF1MAkZ1l4XoxLA5RNvX8RE9Q4+9uab7ReGcZkoGPnvF43C1hTdCqXNSCdddxdXtVdxUVHgEJdokAOovL2Z31nbrbF0RlnpmUkI9xc1mwEhZEOqy0F+Yu8P1o78fyS7vYaVuIWPqYI3/70WjaJaCFzT3/9BybI9k5TmTCkKo+lG/4vp+uYe6iFf2HNYFkjabNalBDzGpyy91PWSpjRtvsdnXMF4eh4W1oSnF112UylRIsWBEapl"
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8b9W7EoETKMuP/1XlE/WQXrJ47U9nbwictLu4caOcrwqUJvdK0X/K919WoxJgbXf8CVB1ezkhyuAiS8jVdMMpdBJ2F1N4AkaYz95cMEf8ZpNN91e+ZtkhChBj2NTRShHodpL6S8CRmFPb+puhDNqjxKiohzv6ogPmAZ5UzL0lUipS/wzrUfmIOLLSEoFsSxo2YamSjHRkomN7H9Fa70IzZPusTe9bD9LOur1OIg3QPPz9O5sAjzn9j6WLIW87y862YkqeKHygvzBZ9kNmaq7ITJq65budfV56lxW2TgT8gby7zmQTuBJOfEwvPe+VjC302BdFdXMO/xjhVLGAv49FMlt6mogr9XMsz2+4z/y0lmv3E//yDGK+WRYWjir6Ew73Q74IIgLmPEkOMZ6LWPgeTbfJ8w774kGfxOCjb8IFGQssG7gMrDGKZTzUygwgnEnW5j11Sd+GwsLRsuvTcUZpkp7U5f7WtHBJKYh3wCMzeXel5HvfYyisjeTz4TKcMPyjeTRSOj9YTI6gDz/BseXyd2iqc45SsbMoqSSs5e3+q3JpsRCn+90U2tEwGyiHAYbAtNgmqK2aaN3lgQA3JKMU8wKe1TW0JdXEawreIfKeFjkRwIHNKKNmEB4CEtxQphmM5Imn1Cgnqqh3DJaWlQur3rfqRJvaiIHg7UlDKFW34Q=="
			"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDVIAe6BXlZmi7LgCQJ34/4D31zxy68XvD/jE4mT7kmsU7wdnStt468Q8KO/SX69kq9WUqGo/mu5/vXk1fgp84onmp2UTdLPsNF9GJ4ppENUULwUosHCz2oF8syqI5Zd0hFhpTdhM1IXDzI+5r/HA85PK0zDUse3c1Oa7kaFcNvpERAifiaERVWzzdY4Q1MOFKWHvYwZXws+p9W5QOdizok/dgfCViZ6O8uDkfd9zlVfyWeAhJqfCPqhWVZrqhEtmIroAbrNIwQD+7WNg1MDG94WO5HV0qqIURhFb/KqoMzKrccu48W/RgzwCRGd9iPMnUXS6jIlYIirdmqUx1tmIfmWTCjr4nhseCl2wAeKRA+ZN2ZE3CiwBjJdF3Fd2fdxaVIXSCbKP7LZgGnIieL4dULOM8wBroSbog7kqGC7ayjYDuCtHZRB638kiTV18+UzkGCvHcLKrLaZ7w0q/5agEASYR+LEKoQojUKV9fPnNRIBHPQMNI5m/nZ7GnW9HtETTcrluu06xwapLm4iLDbe8K7MTKiPdztvea8jC3U5G65itO4RgV6ws1HTTizb041Ks0uT7IW8QKJ/OTjviBgEdQ/sZW8kYVuXPAfHZogTkAHvOMyo17IYOU81qcFPROC0z2AzEcYlDMcds5qeLk2BuqwZva9yeo1WpeWxOcbxPwEbw=="
		];

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

	# temporary, until the new gateway box comes
	services.unifi = {
		enable = true;
		openFirewall = true;
		unifiPackage = pkgs.unifi;
		mongodbPackage = pkgs.mongodb-ce;
	};

	# Open ports in the firewall.
	networking.firewall.allowedTCPPorts = [
		# roon arc
		55000

		# 5etools & other sites
		80
		443

		# unifi controller web
		8443

		# unifi remote management
		5349
	];
	networking.firewall.allowedUDPPorts = [
		# roon arc
		55000
	];
	networking.firewall.checkReversePath = "loose"; # weird dual nic setup

	#### internal site hosting
	services.nginx = {
		enable = true;
		virtualHosts = {
			"5etools.house.metamagical.dev" = {
				serverAliases = [ "5etools" ];
				root = "/web-root/5etools";
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
			};
			"house.metamagical.dev" = {
				serverAliases = [ "house" ];
				root = "/web-root/house";
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
				locations."/dont-copy-this-floppy" = {
					extraConfig = ''
						autoindex on;
					'';
				};
			};
			"ui.house.metamagical.dev" = {
				serverAliases = [ "ui" ];
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
				locations."/" = {
					proxyPass = "https://127.0.0.1:8443";
				};
				locations."/inform" = {
					proxyPass = "http://127.0.0.1:8080";
				};
				locations."/wss" = {
					proxyPass = "https://127.0.0.1:8443";
				};
				extraConfig = ''
					proxy_ssl_verify off;

					proxy_set_header Origin "";
					proxy_set_header Referer "";
				'';
			};
			"calibre.house.metamagical.dev" = {
				serverAliases = [ "calibre" ];
				locations."/" = {
					# calibre server
					proxyPass = "http://127.0.0.1:65002";
					extraConfig = ''
						client_max_body_size 256M;
					'';
				};
				locations."/web" = {
					# calibre web
					proxyPass = "http://127.0.0.1:65003";
					extraConfig = ''
						proxy_set_header X-Script-Name /web;
						rewrite '^/web(/.*)?' /$1 break;
						client_max_body_size 256M;
					'';

				};
				extraConfig = ''
					gzip on;
					gzip_vary on;
					gzip_min_length 1000;
					gzip_proxied any;
					gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
				'';
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
			};
			"kavita.house.metamagical.dev" = {
				serverAliases = [ "kavita" ];
				locations."/" = {
					# calibre server
					proxyPass = "http://127.0.0.1:65004";
					extraConfig = ''
						client_max_body_size 256M;
					'';
				};
				locations."/hubs/" = {
					proxyPass = "http://127.0.0.1:65004";
					extraConfig = ''
						# Headers to proxy websocket connections
						proxy_http_version 1.1;
						proxy_set_header Upgrade $http_upgrade;
						proxy_set_header Connection "Upgrade"; 
					'';
				};
				extraConfig = ''
					# The following configurations must be configured when proxying to Kavita
					# Host and X headers
					proxy_set_header	Host $host;
					proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for; aio threads;
					proxy_set_header        X-Forwarded-Proto $scheme;

					gzip on;
					gzip_vary on;
					gzip_min_length 1000;
					gzip_proxied any;
					gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;

				'';
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
			};
			# TODO: not working
			"plex.house.metamagical.dev" = {
				serverAliases = [ "plex" ];
				locations."/" = {
					proxyPass = "https://127.0.0.1:32400";
				};
				extraConfig = ''
					gzip on;
					gzip_vary on;
					gzip_min_length 1000;
					gzip_proxied any;
					gzip_types text/plain text/css text/xml application/xml text/javascript application/x-javascript image/svg+xml;
					# don't break phone camera upload
					client_max_body_size 100M;

					proxy_set_header Host $host;
					proxy_set_header X-Real-IP $remote_addr;
					proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
					proxy_set_header X-Forwarded-Proto $scheme;
					proxy_set_header Sec-WebSocket-Extensions $http_sec_websocket_extensions;
					proxy_set_header Sec-WebSocket-Key $http_sec_websocket_key;
					proxy_set_header Sec-WebSocket-Version $http_sec_websocket_version;

					#Websockets
					proxy_http_version 1.1;
					proxy_set_header Upgrade $http_upgrade;
					proxy_set_header Connection "Upgrade";

					proxy_redirect off;
					proxy_buffering off;
				'';
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
			};
			"_" = {
				default = true;
				extraConfig = ''
					return 404;
				'';
				acmeRoot = null; # manual setup below
				useACMEHost = "home.metamagical.dev";
				addSSL = true;
			};
		};
	};
	security.acme = {
		acceptTerms = true;
		defaults.email = "directxman12+acme@metamagical.dev";
		certs = {
			"home.metamagical.dev" = {
				group = "nginx";
				domain = "*.home.metamagical.dev";
				dnsProvider = "porkbun";
				environmentFile = "/var/lib/secrets/acme.secret";
				extraDomainNames = [ "*.house.metamagical.dev" "house.metamagical.dev" "home.metamagical.dev" "plex.metamagical.dev" ];
				# TODO: this is needed because internal dns returns a SOA record for home.metamagical.dev
				# (correctly), but when acme-go tries to split the domain it thinks that means it should try for
				# `name = *, domain = home.metamagical.dev`, not `name = *.home, domain = metamagical.dev`.
				dnsResolver = "8.8.8.8:53";
			};
		};
	};

	##### calibre
	services.calibre-server = {
		enable = true;
		host = "127.0.0.1";
		port = 65002;
		libraries = ["/web-root/calibre/library"];
		user = "calibre";
		auth = {
			enable = true;
			mode = "basic";
			userDb = "/web-root/calibre/users.db";
		};
	};
	services.calibre-web = {
		enable = true;
		listen = {
			ip = "127.0.0.1";
			port = 65003;
		};
		options.calibreLibrary = "/web-root/calibre/library";
		user = "calibre";
	};
	###### kavita (calibre-like, but with better support for manga)
	services.kavita = {
		enable = true;
		user = "calibre";
		settings = {
			Port = 65004;
			IpAddresses = "127.0.0.1";
		};
		dataDir = "/web-root/kavita";
		tokenKeyFile = "/web-root/kavita/tokens.key";
	};

	#### misc
	# Enable the OpenSSH daemon.
	services.openssh.enable = true;

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
	};

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
