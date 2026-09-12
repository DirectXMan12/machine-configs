{ pkgs, config, lib, ... }:

{
	config = lib.mkIf config.local.server.enable {
		# Set your time zone.
		time.timeZone = "America/Los_Angeles";
	};
}
