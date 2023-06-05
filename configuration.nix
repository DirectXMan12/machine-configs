# Edit this configuration file to define what should be installed on
# your system.	Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
	nix.settings.experimental-features = [ "nix-command" "flakes" ];

	# Use the systemd-boot EFI boot loader.
	boot = {
		# pretty boot
		plymouth = {
			enable = true;
			theme = "breeze";
		};

		# TODO(directxman12): try out `initrd.systemd.enable` for password prompt in plymouth
		# (see https://github.com/NixOS/nixpkgs/issues/26722)

		# actual boot details
		loader = {
			systemd-boot = {
				enable = true;
				consoleMode = "auto"; # a slightly higher resolution, hopefully
			};
			efi.canTouchEfiVariables = true;
		};
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

	# Enable CUPS to print documents. (in flake.nix for alt config)
	#services.printing.enable = true;

	# Enable sound.
	# sound.enable = true;
	# hardware.pulseaudio.enable = true;
	# NB(directxman12): enabled in another file via pipewire

	# Define a user account. Don't forget to set a password with ‘passwd’.
	users.users.directxman12 = {
		isNormalUser = true;
		extraGroups = [
			"wheel" # Enable ‘sudo’ for the user.
			"networkmanager"
		];
		shell = "/home/directxman12/.nix-profile/bin/zsh";
	};

	# List packages installed in system profile. To search, run:
	# $ nix search wget
	environment.systemPackages = with pkgs; [
		vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
		wget
		curl
	];

	# Some programs need SUID wrappers, can be configured further or are
	# started in user sessions.
	# programs.mtr.enable = true;
	# programs.gnupg.agent = {
	#		enable = true;
	#		enableSSHSupport = true;
	# };

	# List services that you want to enable:

	# Enable the OpenSSH daemon.
	# services.openssh.enable = true;

	# Open ports in the firewall.
	# networking.firewall.allowedTCPPorts = [ ... ];
	# networking.firewall.allowedUDPPorts = [ ... ];
	# Or disable the firewall altogether.
	# networking.firewall.enable = false;

	# Copy the NixOS configuration file and link it from the resulting system
	# (/run/current-system/configuration.nix). This is useful in case you
	# accidentally delete configuration.nix.
	# system.copySystemConfiguration = true;
}

