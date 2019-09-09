# Based on
# https://github.com/input-output-hk/iohk-ops/blob/df01a228e559e9a504e2d8c0d18766794d34edea/jobsets/default.nix

{ nixpkgs ? <nixpkgs>
, declInput ? {}
}:

let

  nixopsUri = "https://github.com/dhess/nixops.git";

  mkFetchGithub = value: {
    inherit value;
    type = "git";
    emailresponsible = false;
  };

  nixpkgs-src = builtins.fromJSON (builtins.readFile ../nixpkgs-src.json);
  nixpkgs-spec = {
    url = "https://github.com/${nixpkgs-src.owner}/${nixpkgs-src.repo}.git";
    rev = "${nixpkgs-src.rev}";
  };

  pkgs = import nixpkgs {};

  defaultSettings = {
    enabled = 1;
    hidden = false;
    keepnr = 20;
    schedulingshares = 100;
    checkinterval = 300;
    enableemail = false;
    emailoverride = "";
    nixexprpath = "release.nix";
    nixexprinput = "nixops";
    description = "My custom NixOps";
    inputs = {
      nixops = mkFetchGithub "${nixopsUri} master";
      nixpkgs = mkFetchGithub "${nixpkgs-spec.url} ${nixpkgs-spec.rev}";
    };
  };

  mkAlternate = nixopsBranch: nixpkgsRev: {
    inputs = rec {
      nixpkgs_override = mkFetchGithub "https://github.com/NixOS/nixpkgs-channels.git ${nixpkgsRev}";
      nixpkgs = nixpkgs_override;
      nixops = mkFetchGithub "${nixopsUri} ${nixopsBranch}";
    };
  };

  mkNixpkgs = nixopsBranch: nixpkgsRev: {
    checkinterval = 60 * 60 * 12;
    schedulingshares = 100;
    inputs = rec {
      nixpkgs_override = mkFetchGithub "https://github.com/NixOS/nixpkgs.git ${nixpkgsRev}";
      nixpkgs = nixpkgs_override;
      nixops = mkFetchGithub "${nixopsUri} ${nixopsBranch}";
    };
  };

  mainJobsets = with pkgs.lib; mapAttrs (name: settings: defaultSettings // settings) (rec {
    master = {};
    # Disabled for now, the "none" test keeps hanging.
    #nixpkgs = mkNixpkgs "master" "master";
  });

  jobsetsAttrs = mainJobsets;

  jobsetJson = pkgs.writeText "spec.json" (builtins.toJSON jobsetsAttrs);

in {
  jobsets = with pkgs.lib; pkgs.runCommand "spec.json" {} ''
    cat <<EOF
    ${builtins.toJSON declInput}
    EOF
    cp ${jobsetJson} $out
  '';
}
