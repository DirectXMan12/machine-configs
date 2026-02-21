{ config, pkgs, lib, ... }:

# if this all doesn't reload properly, try restarting
# nscd.service, which caches name results
# TODO: make this automatic when kanidm config gets changed
let
	cfg = config.metamagical.sso.pam;
in
	with lib;
	{
		options = {
			metamagical.sso.pam = {
				enable = mkEnableOption "sso-based pam";
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
				server = mkOption {
					type = types.str;
					default = mkIf config.metamagical.sso.server.enable "https://${config.metamagical.sso.server.domain}";
					description = "talk to this kanidm instance";
				};
				config-version = mkOption {
					type = types.enum ["2" "2-ish"];
					default = "2";
					description = "whether or not nixos 25.11 weirdness is going on around pam_allowed_login_groups";
				};
			};
		};
		config = mkIf cfg.enable {
			services.kanidm = {
				# client ssh key provisioning and supports the pam module
				enableClient = true;
				# pam enables... pam (i.e. dynamic user login, etc)
				enablePam = true;

				clientSettings.uri = cfg.server;

				unixSettings = {
					version = "2";

					# in a real setup, we'd use uuid + symlink aliases
					# but that seems overly complicated, so just use
					# name directly
					home_attr = "name";
					home_alias = "none";

					# gross, no
					selinux = false;

					# automatically provision people in this group

					# duplicated cause the nixos 25.11 setting hasn't caught up to the
					# kanidm 2.0 format, but is required and in unstable it's disallowed
					# and only the new option is allowed
					pam_allowed_login_groups = lib.mkIf (cfg.config-version == "2-ish") cfg.login-groups;
					kanidm = {
						pam_allowed_login_groups = cfg.login-groups;
						service_account_token_path = "/etc/kanidm/unixd_token";

						# stick admin users in wheel if enabled
						map_group = mkMerge [
							(mkIf (cfg.admin-group != null) [ { local = "wheel"; "with" = cfg.admin-group; } ])
						  (map (group: { local = "users"; "with" = group; }) cfg.login-groups)
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

			systemd.services.nscd = lib.mkIf config.services.nscd.enable {
				after = ["kanidm-unixd.service"];
				wants = ["kanidm-unixd.service"];
				# restart when kanidm is restarted (will stop when it stops too, which
				# is not great, but eh)
				partOf = ["kanidm-unixd.service"]; 
			};

			# Enable the OpenSSH daemon.
			services.openssh.enable = mkDefault config.local.server.enable;
		};
	}
