{ config, lib, pkgs, ... }:

{
	imports = [
		./proxy.nix
		./static.nix
	];
	options = with lib; {
		metamagical.serving = {
			enable = mkEnableOption "web-serving";
		};
	};
}
