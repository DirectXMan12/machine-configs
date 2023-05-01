{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # sway itself, and other bits
    unstable.sway
    wayland
    swaylock  # lock...
    swayidle  # ...and auto-lock
    slurp
    sway-contrib.grimshot # screenshots (wraps grim & slurp)
    wl-clipboard # on the tin
    waybar # status bar
    mako # notifications
    kanshi # hotplug monitors
    tofi # dmenu replacement for wayland that works nicely
    jq # required for named workspaces to work

    # terminal and other core pieces that are wayland dependent
    alacritty # terminal
    networkmanagerapplet # for the indicator

    # other windowing-related stuff
    xdg-utils # for xdg-open
    gnome3.adwaita-icon-theme # for cursors and such
    pavucontrol # needed to manage sound, waybar sound item
  ];

  # screensharing support:
  # first pipewire...
  security.rtkit.enable = true; # reccomended by nixos pipewire page, auto-adjusts priorities and such
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
  # ...then the portal service for wlroots
  services.dbus.enable = true;
  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings = {
        screencast = {
          chooser_cmd = "slurp -f %o -or";
          chooser_type = "simple";
        };
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
  # we also *miiiight* need to restart pipewire and such to ensure they get the right session variables according to the sway page on the nixos wiki, but lets see, but let's see

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    wrapperFeatures.base = true;
  };

  # for waybar
  fonts.fonts = with pkgs; [
    # for waybar
    font-awesome
    (nerdfonts.override { fonts = [ "DejaVuSansMono" ]; })
  ];
}
