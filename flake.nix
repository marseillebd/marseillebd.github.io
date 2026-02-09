{
  description = "Development environment for my git pages site";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  } @ args:
  flake-utils.lib.eachDefaultSystem (system:
  let

    pkgs = import nixpkgs { inherit system; };

  in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          just # for a justfile that holds common commands
          pandoc # to generate html from markdown
        ];
        shellHook = ''
          . .profile.sh
        '';
      };
    }
  );
}
