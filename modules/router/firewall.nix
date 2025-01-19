{ config, pkgs, lib, ... }:

{
	config = {
		networking.nftables = {
			enable = true;
			ruleset = builtins.readFile ./scratch.real.nft;
		};
	};
}
