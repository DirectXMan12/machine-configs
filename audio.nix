{ config, pkgs, ... }:

{
	environment.etc = {
		"pipewire/pipewire.conf.d/90-hiqual.conf".text = ''
			context.properties = {
				default.clock.rate = 96000
				default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ]
			}
		'';
	};
}
