{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      # This discussion inspired me
      # https://discourse.nixos.org/t/best-practices-for-expo-react-native-development-with-devenv/58776/5
      #
      # What we want to do here is just provision the listed packages below,
      # without the clang compiler nor Apple SDK.
      # So we need to undo some side effects of mkShellNoCC.
      {
        # Use mkShellNoCC instead of mkShell so that it wont pull in clang.
        # We need to use the clang from Xcode.
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            pkgs.nodejs_20
            # GitHub Actions runner macos-14 uses ruby 3.3.x
            # See https://github.com/actions/runner-images/blob/main/images/macos/macos-14-arm64-Readme.md
            pkgs.ruby_3_3
          ];
          # Even we use mkShellNoCC, DEVELOPER_DIR, SDKROOT, MACOSX_DEPLOYMENT_TARGET is still set.
          # We undo that.
          #
          # Also, xcrun from Nix is put in PATH, we want to undo that as well.
          shellHook = ''
            export PATH=$(echo $PATH | sed "s,${pkgs.xcbuild.xcrun}/bin,,")
            unset DEVELOPER_DIR
            unset SDKROOT
            unset MACOSX_DEPLOYMENT_TARGET
          '';
        };
      }
    );
}
