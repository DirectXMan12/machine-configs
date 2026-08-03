{ config, pkgs, lib, ... }:

with lib; {
	metamagical.sso.pam = mkIf config.local.server.enable {
		enable = true;
		config-version = "2";
		server = mkDefault "https://sso.metamagical.house";
	};

	services.kanidm.unixSettings.allow_local_account_override = ["directxman12"];
}
