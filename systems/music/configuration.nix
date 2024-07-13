{ config, pkgs, lib, ... }:

{
	networking.hostName = "music";

	#### roon & plex
	nixpkgs.overlays = lib.mkAfter [
		(pkgfinal: pkgprev: {
			roon-server = pkgprev.roon-server.overrideAttrs (final: prev: {
				version = "2.0-1438";
				urlVersion = builtins.replaceStrings [ "." "-" ] [ "00" "0" ] final.version;
				src = pkgs.fetchurl {
					url = "https://download.roonlabs.com/updates/earlyaccess/RoonServer_linuxx64_${final.urlVersion}.tar.bz2";
					hash = "sha256-NzrEiJeUgoASH6yM1qZXR4lELIsUrKV6uRBpePpMcYU=";
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
	};

	users.groups = {
		music-players = {
			members = [ "roon-server" "plex" ];
			gid = 993; # stable gid for /roon-music mount
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
			version = "1.32.8.7639-fb6452ebf";
			src = pkgs.fetchurl {
				url = "https://downloads.plex.tv/plex-media-server-new/${final.version}/debian/plexmediaserver_${final.version}_amd64.deb";
				sha256 = "sha256-jdGVAdvm7kjxTP3CQ5w6dKZbfCRwSy9TrtxRHaV0/cs=";
			};
		});
	};

	# Open ports in the firewall.
	networking.firewall.allowedTCPPorts = [
		# roon arc
		55000

		# 5etools & other sites
		80
		443
	];
	networking.firewall.allowedUDPPorts = [
		# roon arc
		55000
	];

	#### internal site hosting
	services.nginx = {
		enable = true;
		virtualHosts = {
			"5etools.home.metamagical.dev" = {
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
				extraDomainNames = [ "house.metamagical.dev" "home.metamagical.dev" ];
			};
		};
	};

	#### misc
	# Enable the OpenSSH daemon.
	services.openssh.enable = true;

	networking.firewall.checkReversePath = "loose"; # weird dual nic setup 

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
