{ config, lib, ... }:

{
	# TODO: remove when github:NixOS/nixpkgs#55674 lands
	options.allowedUnfree = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
	config.nixpkgs.config.allowUnfreePredicate = p: builtins.elem (p.pname or (builtins.parseDrvName p.name).name) config.allowedUnfree;
}
