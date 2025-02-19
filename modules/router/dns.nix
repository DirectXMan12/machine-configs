{ config, pkgs, lib, ... }:

let
  routerCfg = config.router;
  cfg = config.router.dns;
  toml = pkgs.formats.toml {};

  removeNulls = attrs: lib.filterAttrsRecursive (n: v: v != null) attrs;

  # TODO: move these into a shared utility module
  dhcpServerFaces = lib.attrsets.filterAttrs (name: iface: iface.type == "lan" && lib.lists.any (addr: addr.v4.dhcp.enable) iface.addresses) routerCfg.interfaces;
  dhcpServerFaceNames = lib.attrsets.mapAttrsToList (name: iface: name) dhcpServerFaces;

  dhcpDynDNSAddrs = let
    dynAddrsForFace = iface: lib.lists.filter (addr: addr.v4.dhcp.dynDNS) iface.addresses;
    allAddrs = lib.attrsets.mapAttrsToList (name: iface: dynAddrsForFace iface) dhcpServerFaces;
  in
    lib.lists.flatten allAddrs;
  
  hasDynDNS = builtins.length dhcpDynDNSAddrs > 0;

  lanAddresses = let
    onlyLan = lib.lists.filter (iface: iface.type == "lan") (lib.attrsets.attrValues routerCfg.interfaces);
  in
    lib.lists.concatMap (iface: lib.lists.map (addr: addr.address)) onlyLan;
  
  # sadly, nixos doesn't package the default zone files, so replicate them here
  # NB: indented strings don't work with tabs
  defaultZones =
    let
      soa = ''
        $TTL 3D
        @               IN      SOA     ${cfg.authority}. internal-dns.${cfg.authority}. (
                199609203 ; Serial
                28800     ; Refresh
                7200      ; Retry
                604800    ; Expire
                86400)    ; Minimum TTL
              NS      ${cfg.authority}.
      '';
    in
      {
        "localhost" = {
          type = "primary";
          file = pkgs.writeText "localhost.zone" ''
            ${soa}
            
            localhost.              A        127.0.0.1
                                    AAAA     ::1
          '';
        };
        "0.0.127.in-addr-arpa" = {
          type = "primary";
          file = pkgs.writeText "127.0.0.1.zone" ''
            ${soa}

            1                      PTR       localhost.
          '';
        };
        "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa" = {
          type = "primary";
          file = pkgs.writeText "ipv6_1.zone" ''
            ${soa}

            1                      PTR       localhost.
          '';
        };
        "255.in-addr.arpa" = {
          type = "primary";
          file = pkgs.writeText "255.zone" soa;
        };
        "0.in-addr.arpa" = {
          type = "primary";
          file = pkgs.writeText "0.zone" soa;
        };
      };
  rootZones = {
    "." = {
      type = "external";
      stores = [{
        recursor = { 
          roots = ./root.zone;
          ns_cache_size = 1024;
          record_cache_size = 1048576;
          recursion_limit = 12;
          ns_recursion_limit = 16;
          cache_policy = {
            default.positive_max_ttl = 86400;
            A.positive_max_ttl = 3600;
            AAAA.positive_max_ttl = 3600;
          };
        };
      }];
    };
  };
  cfgForStore = stores: builtins.head (lib.attrsets.mapAttrsToList (name: store: {
    type = name;
  } // removeNulls (lib.attrsets.filterAttrs (name: _: name != "extraConfig") store)) stores);

  dynZones = with lib; (let
    soa = ''
      $TTL 3D
      @               IN      SOA     ${cfg.authority}. internal-dns.${cfg.authority}. (
              199609203 ; Serial
              28800     ; Refresh
              7200      ; Retry
              604800    ; Expire
              86400)    ; Minimum TTL
            NS      ${cfg.authority}.
    '';
    # TODO: tsig and/or limit to coming from localhost
    zones = lists.concatMap (addr: [
      {
        # forward
        name = addr.v4.dhcp.domainName;
        value = {
          type = "primary";
          stores = [{
            sqlite = {
              zone_file_path = pkgs.writeText "dyn-${addr.v4.dhcp.domainName}.zone" "${soa}";
              journal_file_path = "dyn-${addr.v4.dhcp.domainName}.jrnl";
              allow_update = true;
            };
          }];
        };
      }
      {
        # reverse
        name = let
          split = lib.strings.splitString "." addr.address;
          reversed = lib.lists.reverseList split;
          reversedStr = lib.strings.concatStringsSep "." reversed;
        in
          "${reversedStr}.in-addr.arpa";
        value = {
          type = "primary";
          stores = [{
            sqlite = {
              zone_file_path = pkgs.writeText "dyn-rev-${addr.v4.dhcp.domainName}.zone" "${soa}";
              journal_file_path = "dyn-rev-${addr.v4.dhcp.domainName}.jrnl";
              allow_update = true;
            };
          }];
        };
      }
    ]) dhcpDynDNSAddrs;
  in 
    builtins.listToAttrs zones);

  zoneTypes = {
    primary = "Primary";
    secondary = "Secondary";
    external = "External";
  };

  # submodule config
  # TODO: make these names conform, and then covert them back to toml names
  blocklistOptions = with lib; mkOption {
    type = types.submodule {
      options = {
          wildcard_match = mkOption { type = types.nullOr types.bool; default = null; };
          min_wildcard_depth = mkOption { type = types.nullOr types.int; default = null; };
          lists = mkOption { type = types.listOf (types.either types.path types.str); };
          sinkhole_ipv4 = mkOption { type = types.nullOr types.str; default = null; };
          sinkhole_ipv6 = mkOption { type = types.nullOr types.str; default = null; };
          ttl = mkOption { type = types.nullOr types.int; default = null; };
          block_message = mkOption { type = types.nullOr types.str; default = null; };
          # TODO: use apply to covert this to the right case, and have these be lower case
          consult_action = mkOption { type = types.nullOr (types.enum ["Disabled" "Enforce" "Log"]); default = null; };

          extraConfig = mkOption { type = types.attrsOf toml.type; default = {}; };
      };
    };
  };
  ttlOptions = with lib; {
    options = {
        positive_min_ttl = mkOption { type = types.nullOr types.int; default = null; };
        negative_min_ttl = mkOption { type = types.nullOr types.int; default = null; };
        positive_max_ttl = mkOption { type = types.nullOr types.int; default = null; };
        negative_max_ttl = mkOption { type = types.nullOr types.int; default = null; };
    };
  };
  recursorOptions = with lib; mkOption {
    type = types.submodule {
      options = {
        roots = mkOption { type = types.path; };
        ns_cache_size = mkOption { type = types.nullOr types.int; default = null; };
        record_cache_size = mkOption { type = types.nullOr types.int; default = null; };
        recursion_limit = mkOption { type = types.nullOr types.int; default = null; };
        ns_recursion_limit = mkOption { type = types.nullOr types.int; default = null; };
        cache_policy = mkOption { type = types.attrsOf (types.submodule ttlOptions); default = {}; };

        extraConfig = mkOption { type = types.attrsOf toml.type; default = {}; };
      };
    };
  };
  forwardOptions = with lib; mkOption {
    type = types.submodule {
      options = {
        # TODO: define these
        extraConfig = mkOption { type = types.attrsOf toml.type; default = {}; };
      };
    };
  };
  fileStoreOptions = with lib; mkOption {
    type = types.submodule {
      options = {
        zone_file_path = mkOption { type = types.path; };
      };
    };
  };
  sqliteStoreOptions = with lib; mkOption {
    type = types.submodule {
      options = {
        zone_file_path = mkOption { type = types.path; };
        journal_file_path = mkOption { type = types.str; };
        allow_update = mkOption { type = types.bool; };
      };
    };
  };
  storeOptions = with lib; (types.attrTag {
    blocklist = blocklistOptions;
    recursor = recursorOptions;
    forward = forwardOptions;
    file = fileStoreOptions;
    sqlite = sqliteStoreOptions;
  });
  zoneOptions = with lib; {
    options = {
      type = mkOption {
        type = types.enum ["primary" "secondary" "external"];
      };
      # TODO: check for either file or stores
      file = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
      stores = mkOption {
        # TODO: check that this is ether external stores or stores, depending
        type = types.listOf storeOptions;
        default = [];
      };
      extraConfig = mkOption {
        type = types.attrsOf toml.type;
        default = {};
      };
    };
  };
in
  {
    options.router.dns = with lib; {
      enable = mkEnableOption "DNS server";
      # TODO: it'd be nice to pull this from addresses, but that'd require
      # views likely, so not quite yet for hickory
      authority = mkOption {
        type = types.str;
      };
      resolve = mkOption {
        type = types.bool;
      };
      zones = mkOption {
        type = types.attrsOf (types.submodule zoneOptions);
        default = {};
      };
      extraConfig = mkOption {
        type = types.attrsOf toml.type;
        default = {};
      };
      listenOn = mkOption {
        type = types.str;
        default = lanAddresses;
      };
      serveDefaultZones = mkOption {
        type = types.bool;
        default = true;
      };
      serveDynDnsZones = mkOption {
        type = types.bool;
        default = true;
      };
    };

    config = lib.mkIf cfg.enable (with lib; {
      router.dns.zones = mkMerge [
        (mkIf cfg.serveDefaultZones defaultZones)
        (mkIf cfg.serveDynDnsZones dynZones)
        (mkIf cfg.resolve rootZones)
      ];

      # hickory handles this
      services.resolved.enable = false;
      services.hickory-dns = {
        enable = true;
        settings = {};
        package = pkgs.rustPlatform.buildRustPackage rec {
          version = "0.25.0-alpha.5";
          pname = "hickory-dns";

          src = pkgs.fetchFromGitHub {
            owner = "hickory-dns";
            repo = "hickory-dns";
            tag = "v${version}";
            hash = "sha256-dbtdTvwm1DiV/nQzTAZJ7CD5raId9+bGNLrS88OocxI=";
          };
          cargoHash = "sha256-lBxCGR4/PrUJ0JLqBn/VzJY47Yp8M4TRsYfCsZN17Ek=";
          useFetchCargoVendor = true;
          buildInputs = [ pkgs.openssl ];
          buildFeatures = [ "recursor" "blocklist" ];
          nativeBuildInputs = [ pkgs.pkg-config ];
          doCheck = false;
          meta.mainProgram = "hickory-dns";
        };
        configFile = let
          allZones = attrsets.mapAttrsToList (name: zone: removeNulls ({
            zone = name;
            zone_type = zoneTypes."${zone.type}";
            file = zone.file;
            stores = lists.map cfgForStore zone.stores;
          } // zone.extraConfig)) cfg.zones;
          generated = {
            # TODO: listen addrs
            zones = allZones;
            directory = config.services.hickory-dns.settings.directory;
          };
          settings = generated // cfg.extraConfig;
          cleanSettings = removeNulls settings;
        in
          toml.generate "hickory-dns.toml" cleanSettings;
      };
    });
  }
