{ lib, config, ... }:

with lib;
{
	imports = [
		./client.nix
		./server.nix
	];
}
