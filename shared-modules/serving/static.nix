{ config, lib, pkgs, ... }:

let
	cfg = config.metamagical.serving;
	proxy-lib = import ./lib.nix { inherit lib; };
in
{
	options = with lib; {
		metamagical.serving = {
			static-sites = let
				site-cfg = types.submodule {
					options = {
						root = mkOption {
							type = types.nullOr (types.either types.path types.str);
							default = null;
							description = "site content";
						};
						redirect = mkOption {
							type = types.nullOr (types.submodule {
								options = {
									from = mkOption { type = types.str; description = "from path"; };
									to = mkOption { type = types.str; description = "to domain + path"; };
									code = mkOption { type = types.int; default = 302; description = "redirect code"; };
								};
							});
							default = null;
							description = "redirect here instead of serving site content";
						};
						proxy-config = mkOption {
							type = proxy-lib.domain-cfg;
							description = "actual proxy config for this site";
						};
					};
				};
			in
				mkOption {
					type = types.attrsOf site-cfg;
					default = [];
					description = "static-content sites to serve";
				};
		};
	};

	config = lib.mkIf cfg.enable {
		# TODO: redirect xor root assertion
		services.static-web-server = {
			enable = true;
			listen = "[::1]:18080";
			# uugh, should patch the nixos module to better support this
			root = "/run/static-web-server"; # since we can't have root = /dev/null
			configuration.advanced = {
					virtual-hosts = lib.mapAttrsToList (name: site: {
						host = name;
						root = site.root;
					}) (lib.filterAttrs (domain: site: site.root != null) cfg.static-sites);
					redirects = lib.mapAttrsToList (name: site: {
						host = name;
						source = site.redirect.from;
						destination = site.redirect.to;
						kind = site.redirect.code;
					}) (lib.filterAttrs (_domain: site: site.redirect != null) cfg.static-sites);
			};
		};
		systemd.services.static-web-server.serviceConfig = {
			BindReadOnlyPaths = lib.mkForce (builtins.concatStringsSep " " (lib.mapAttrsToList (_host: site: site.root) (lib.filterAttrs (_host: site: site.root != null) cfg.static-sites)));
			RuntimeDirectory = "static-web-server";
		};
		services.proxy-in-anger.domains = builtins.mapAttrs (_name: site: lib.mkMerge [
			site.proxy-config
			{ backends.http = [{addr = "[::1]:18080";}]; }
		]) cfg.static-sites;
	};
}
