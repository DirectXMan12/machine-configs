{ config, pkgs, ... }:

{
	nix = {
		# enable lix, nix for lesbians
		package = pkgs.lix;
		# support flakes
		settings.experimental-features = [ "nix-command" "flakes" ];
	};

	# Pick only one of the below networking options.
	# networking.wireless.enable = true;	# Enables wireless support via wpa_supplicant.
	networking.networkmanager.enable = true;	# Easiest to use and most distros use this by default.

	# Set your time zone.
	time.timeZone = "America/Los_Angeles";

	# Select internationalisation properties.
	i18n.defaultLocale = "en_US.UTF-8";
	console = {
		# font = "Lat2-Terminus16";
		keyMap = "us";
	};

	# List packages installed in system profile. To search, run:
	# $ nix search wget
	environment.systemPackages = with pkgs; [
		# emergency stuff, most other things should go
		# in home-manager configs
		vim
		wget
		curl
		git # needed for managing this config
	];
}
