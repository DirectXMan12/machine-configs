{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
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
	};

	users.groups = {
		music-players = {
			members = [ "roon-server" "plex" ];
			gid = 993; # stable gid for /roon-music mount
		};
	};

	environment.systemPackages = lib.mkAfter (with pkgs; [
		# TODO: i think these are bundled into the roon packaging in nixos now
		# roon
		ffmpeg
		cifs-utils
	]);

	allowedUnfree = lib.mkAfter [
		"roon-server"
	];

	services.roon-server = {
		enable = true;
		openFirewall = true;
		user = "roon-server"; # explict to match up with stable-uid stuff above
	};

	networking.firewall = {
		allowedTCPPorts = [
			# roon arc
			55000
		];
		allowedUDPPorts = [
			# roon arc
			55000
		];
	};

	networking.firewall.checkReversePath = "loose"; # weird dual nic setup
}
