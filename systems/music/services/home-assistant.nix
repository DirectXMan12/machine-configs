{ config, pkgs, lib, nixpkgs-unstable, ... }:

{
	# use home-assistant from unstable
	disabledModules = [
		"services/home-automation/matter-server.nix"
		"services/home-automation/home-assistant.nix"
	];
	imports = [
		"${nixpkgs-unstable}/nixos/modules/services/home-automation/matterjs-server.nix"
		"${nixpkgs-unstable}/nixos/modules/services/home-automation/home-assistant.nix"
	];

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
}
