{ config, pkgs, ... }:

{
	# Define a user account. Don't forget to set a password with ‘passwd’.
	users.users.directxman12 = {
		isNormalUser = true;
		extraGroups = [
			"wheel" # Enable ‘sudo’ for the user.
			"networkmanager"
		];
		shell = "/home/directxman12/.nix-profile/bin/zsh";
	};
}
