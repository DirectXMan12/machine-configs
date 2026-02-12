{ config, pkgs, lib, ... }:

{
	# only enable user provisioning on machines that don't have pam set up...
	users.users.directxman12 = lib.mkIf (!config.local.server.enable) {
		isNormalUser = true;
		extraGroups = [
			"wheel" # Enable ‘sudo’ for the user.
			"networkmanager"
		];
	};
	# ... but if that's enabled, provision a fallback user since root can't log in directly
	users.users.breakglass = lib.mkIf (config.local.server.enable) {
		isNormalUser = true;
		extraGroups = [
			"wheel" # Enable ‘sudo’ for the user.
		];
	};
}
