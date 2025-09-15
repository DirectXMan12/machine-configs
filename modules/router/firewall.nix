{ config, pkgs, lib, ... }:

let
    cfg = config.router.firewall;
    routerCfg = config.router;
    lanFaces = lib.attrsets.filterAttrs (name: iface: iface.type == "lan") routerCfg.interfaces;
    wanFaces = lib.attrsets.filterAttrs (name: iface: iface.type == "wan") routerCfg.interfaces;
    wgFaces = lib.attrsets.filterAttrs (name: iface: iface.type == "wireguard") routerCfg.interfaces;
    toCidr = addr: "${addr.address}/${toString addr.mask}";
in
  {
    options.router.firewall = with lib; {
      enable = mkEnableOption "Firewall";
      priorityOffset = mkOption {
        type = types.int;
        default = 10;
      };
      portForwards = mkOption {
        type = types.listOf (types.submodule {
          options = {
            to = mkOption { type = types.str; };
            # TODO: types.enum
            protocol = mkOption { type = types.str; };
            port = mkOption { type = types.either types.int types.str; };
            comment = mkOption { type = types.str; default = ""; };
          };
        });
        default = [];
      };
      inetChains = mkOption {
        type = types.submodule {
          options = {
            input = mkOption { type = types.str; default = ""; };
            forward = mkOption { type = types.str; default = ""; };
            extra = mkOption { type = types.str; default = ""; };
          };
        };
        default = {};
      };
      ipChains = mkOption {
        type = types.str;
        default = "";
      };
    };
    config = lib.mkIf cfg.enable (with lib; {
      networking.nftables = {
        enable = true;
        tables.filterFirewall = {
          family = "inet";
          content = ''
            # see also whois.ripe.net fltr-martian (and fltr-martian-v6)
            set v4_martians {
              type ipv4_addr;
              flags constant, interval;
              auto-merge;
              elements = {
                0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12,
                192.0.0.0/24, 192.0.2.0/24, 224.0.0.0/3, 192.168.0.0/16, 198.18.0.0/15,
                198.51.100.0/24, 203.0.113.0/24
              };
            };
            set v6_martians {
              type ipv6_addr;
              flags constant, interval;
              auto-merge;
              elements = {
                0000::/8, 0064:ff9b::/96, 0100::/8, 0200::/7, 0400::/6, 0800::/5, 1000::/4,
                2001::/32, 2001:0002::/48, 2001:0003::/32, 2001:10::/28, 2001:20::/28,
                2001:db8::/32, 2002::/16, 3ffe::/16, 4000::/3, 5f00::/8, 6000::/3, 8000::/3,
                a000::/3, c000::/3, e000::/4, f000::/5, f800::/6, fc00::/7, fe80::/10,
                fec0::/10, ff00::/8
              };
            };

            ${
              builtins.concatStringsSep "\n" 
                (lists.flatten (attrsets.mapAttrsToList
                  (_: iface: lists.map (addr:
                    ''
                      set ${addr.alias}_addrs {
                        type ipv4_addr;
                        flags interval, constant;
                        elements = {
                          ${toCidr addr}
                        };
                      };
                    ''
                  ) iface.addresses)
                  (lanFaces // wgFaces)))
            }

            set wan_faces {
              type ifname;
              flags constant;
              elements = {
                ${builtins.concatStringsSep ", " (attrsets.mapAttrsToList (name: _: name) wanFaces)}
              }
            };
            set lan_faces {
              type ifname;
              flags constant;
              elements = {
                ${builtins.concatStringsSep ", " (attrsets.mapAttrsToList (name: _: name) lanFaces)}
              }
            };

            # TODO: antilockout rule (allow ssh from lan, explicitly, at high priority, don't follow other rules)
            # TODO: flow table offloading

            # input to the router (i.e. not forwarding)
            chain baseInput {
              type filter hook input priority filter+${toString cfg.priorityOffset}; policy drop;
              
              # anything on the loopback
              iifname "lo" accept;

              # TODO: config for this
              iifname @wan_faces icmp type echo-request limit rate 20/second accept;
              iifname @wan_faces icmpv6 type echo-request limit rate 20/second accept;

              # allow common icmp stuff that's required for the internet to work
              # (http://shouldiblockicmp.com/)
              icmp type { echo-request, echo-reply, time-exceeded, destination-unreachable, parameter-problem } accept;
              icmpv6 type { echo-request, echo-reply, packet-too-big, time-exceeded } accept;
              icmpv6 type { nd-router-solicit, nd-router-advert, nd-neighbor-solicit,
                            nd-neighbor-advert, nd-redirect, parameter-problem } counter accept comment "ipv6 slaac and ndp";
              # allow dhcpv6
              iifname @wan_faces ip6 daddr fe80::/64 udp dport 546 counter accept comment "dhcpv6";

              ${cfg.inetChains.input}

              # allow established traffic from the outside
              iifname @wan_faces ct state { established, related } counter accept;
              iifname @wan_faces drop;
            }

            # actual routing stuff
            chain baseForward {
              # last hop, drop things if not forwarded already
              type filter hook forward priority filter+${toString cfg.priorityOffset}; policy drop;

              ${cfg.inetChains.forward}

              # accept anything that's being dnat-ed
              ct status dnat counter accept;
              counter drop;
            };

            ${cfg.inetChains.extra}
          '';
        };
        tables.natFirewall  = {
          # ipv4 only for nat
          family = "ip";
          content = ''
            set wan_faces {
              type ifname;
              flags constant;
              elements = {
                ${builtins.concatStringsSep ", " (attrsets.mapAttrsToList (name: _: name) wanFaces)}
              }
            };
            set portforward_addrs {
              type ipv4_addr;
              flags constant;
              elements = {
                ${builtins.concatStringsSep ", " (lists.unique (lists.map (forward: forward.to) cfg.portForwards))}
              };
            };

            chain portforwards {
              type nat hook prerouting priority dstnat+${toString cfg.priorityOffset}; policy accept;

              ${
                builtins.concatStringsSep "\n" (
                  lists.map (forward:
                    "${forward.protocol} dport ${toString forward.port} counter dnat to ${forward.to} comment \"${forward.comment}\";"
                  ) cfg.portForwards
                )
              }
            };

            chain basePostrouting {
              type nat hook postrouting priority srcnat+${toString cfg.priorityOffset}; policy accept;

              # TODO: is this randomized?
              # auto (randomized??) snat anything heading out on ipv4
              oifname @wan_faces masquerade;

              ct status dnat ip daddr @portforward_addrs masquerade;
            };

            ${cfg.ipChains}
          '';
        };
      };
    });
  }
