{ config, pkgs, lib, ... }:

{
	allowedUnfree = lib.mkAfter [
		"google-chrome-dev"
		"google-chrome"
		"google-chrome-beta"
		"steam"
		"steam-original"
		"steam-run"
		"steamcmd"
	];
	environment.systemPackages = with pkgs; [
		# consider using the first-party flake in neovim/neovim for nightly once it builds again
		unstable.neovim # v0.9
		bat
		fd
		ripgrep
		# temporary, till it's in nixos, otherwise we get sigsegvs on google drive
		# ((unstable.google-chrome.overrideAttrs (final: prev: {
		# 	name = "google-chrome-dev-${final.version}";
		# 	version = "124.0.6356.2";
		# 	src = pkgs.fetchurl {
		# 		url = "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-unstable/google-chrome-unstable_${final.version}-1_amd64.deb";
		# 		hash = "sha256-4245YF7Jet3n2bcNtovha27C0YW6QyvDz4r/M+Nsiuw=";
		# 	};
		# 	# nacl_helper was removed?
		# 	installPhase = builtins.replaceStrings [",nacl_helper"] [""] prev.installPhase;
		# })).override {
		# 	channel = "dev";
		# })
		# grr, switch back to stable until upstream reverses their decision or i have enough brain to carry a channel patch
		google-chrome

		# needed for flakes when git is present
		git
	];

	programs.neovim = {
		enable = true;
		# use unstable from above
		package = pkgs.unstable.neovim-unwrapped;

		# set {vi,vim} to nvim
		viAlias = true;
		vimAlias = true;
		defaultEditor = true;
	};
}
