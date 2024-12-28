{ config, lib, ... }:

with lib;
{
	options = {
		local.cache.enable = mkEnableOption "personal cachix binary cache";
	};

	config = mkIf (config.local.cache.enable) {
		nix = {
			settings = {
				substituters = [
					"https://directxman12.cachix.org"
				];
				trusted-public-keys = [
					"directxman12.cachix.org-1:JSNhBrYD9cUW/afQzCPaEYtCJNIVhpJeO0ewTDP2j5U="
				];
			};
		};
	};
}
