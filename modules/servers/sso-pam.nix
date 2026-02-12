{ config, pkgs, lib, ... }:

# if this all doesn't reload properly, try restarting
# nscd.service, which caches name results
# TODO: make this automatic when kanidm config gets changed
let
	cfg = config.local.server.pam;
in
	with lib;
	{
		options = {
			local.server.pam = {
				login-groups = mkOption {
					type = types.listOf types.str;
					default = ["auto_pam"];
					description = "a member of any group will be allowed to log in via pam";
				};
				admin-group = mkOption {
					type = types.nullOr types.str;
					default = "pam_admins";
					description = "a member of this group will be granted wheel";
				};
			};
		};
		config = mkIf config.local.server.enable {
			services.kanidm = {
				# client ssh key provisioning and supports the pam module
				enableClient = true;
				# pam enables... pam (i.e. dynamic user login, etc)
				enablePam = true;

				clientSettings.uri = "https://sso.metamagical.house";

				unixSettings = {
					version = "2";

					# in a real setup, we'd use uuid + symlink aliases
					# but that seems overly complicated, so just use
					# name directly
					home_attr = "name";
					home_alias = "none";

					# gross, no
					selinux = false;

					# allow this to configure my local account, when already present
					allow_local_account_override = ["directxman12"];

					# automatically provision people in this group
					pam_allowed_login_groups = cfg.login-groups;
					kanidm = {
						# duplicated cause the nixos setting hasn't caught up to the kanidm 2.0 format
						pam_allowed_login_groups = cfg.login-groups;
						service_account_token_path = "/etc/kanidm/unixd_token";

						# stick admin users in wheel if enabled
						map_group = mkIf (cfg.admin-group != null) [
							{ local = "wheel"; "with" = cfg.admin-group; }
						];
					};
				};
				package = pkgs.kanidm_1_8;
			};

			# set up auto-ssh-key provisioning
			services.openssh = {
				authorizedKeysCommand = "/run/wrappers/bin/kanidm_ssh_authorizedkeys %u";
			};
			security.wrappers.kanidm_ssh_authorizedkeys = {
				# hack around sshd being grumpy about the nix store being group-writable
				source = "${config.services.kanidm.package}/bin/kanidm_ssh_authorizedkeys";
				owner = "root";
				group = "root";
			};

			# Enable the OpenSSH daemon.
			services.openssh.enable = mkDefault config.local.server.enable;
		};
	}
