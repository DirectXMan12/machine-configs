{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
    "google-chrome-dev"
    "google-chrome"
    "google-chrome-beta"
  ];
  environment.systemPackages = with pkgs; [
    # consider using the first-party flake in neovim/neovim for nightly once it builds again
    unstable.neovim # v0.9
    bat
    fd
    ripgrep
    # dev crashes on fullscreen & pipewire atm
    unstable.google-chrome-beta
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
