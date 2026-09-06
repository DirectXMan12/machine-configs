{ config, pkgs, lib, ... }:

with lib; {
	metamagical.sso.pam = mkIf config.local.server.enable {
		enable = true;
		config-version = "2";
		server = mkDefault "https://sso.metamagical.house";
	};

	services.kanidm.unixSettings.allow_local_account_override = ["directxman12"];

	security.pam = {
		rssh = {
			enable = true;
			settings = {
				# use kanidm's authorized keys
				# can't used services.openssh.authorizedKeysCommand cause it has a
				# `%u`, which rssh passes implicitly
				authorized_keys_command = "${config.security.wrapperDir}/kanidm_ssh_authorizedkeys";
				authorized_keys_command_user = config.services.openssh.authorizedKeysCommandUser;
				auth_key_file = null;
				cue = true;
				cue_prompt = "touch your security key";
			};
		};

		# order sudo such that unix [sufficient] --> check(user != breakglass) --> kanidm[necessary] --> rssh [sufficient]
		# meaning everyone but breakglass needs 2fa, and breakglass can't auth thru kanidm
		services."sudo" = {
			rssh = true;
			rules.auth = {
				# check(user != breakglass)
				deny-breakglass-kanidm = {
					enable = true;
					order = config.security.pam.services."sudo".rules.auth.kanidm.order - 1;
					control = "[success=ignore default=bad]"; # pass if succeeds, fail-ish otherwise
					modulePath = "${config.security.pam.package}/lib/security/pam_succeed_if.so";
					args = [
						"quiet"
						"user"
						"!="
						"breakglass"
					];
				};
				# kanidm[required]
				kanidm.control = lib.mkForce "required";
				# rssh[sufficient]
				rssh.order = lib.mkForce (config.security.pam.services."sudo".rules.auth.kanidm.order + 1);
			};
		};
	};
}
