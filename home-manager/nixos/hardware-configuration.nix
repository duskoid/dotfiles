# PLACEHOLDER hardware configuration.
#
# !!! Replace this file on the real machine before (or right after) installing:
#
#   sudo nixos-generate-config --show-hardware-config \
#     > ~/dotfiles/home-manager/nixos/hardware-configuration.nix
#
# The generated file contains your actual CPU, GPU, kernel modules, disks and
# fileSystems. The values below are generic guesses that let the flake evaluate
# on other machines — they are NOT a working boot config for real hardware.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ]; # e.g. "kvm-amd" / "kvm-intel" after generate-config
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
