# NixOS system configuration for the heavy box.
#
# This file is imported by ../flake.nix (nixosConfigurations.tower) together
# with the home-manager module. User-level config (packages, dotfiles, zsh)
# still comes from ../home.nix and ../shell.nix with isNixOS = true.
#
# After installing NixOS on the real machine, replace
# ./hardware-configuration.nix with the output of:
#   sudo nixos-generate-config --show-hardware-config
{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # --- Bootloader (UEFI + systemd-boot) --------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- NVIDIA -----------------------------------------------------------------
  # Proprietary drivers. For Turing (GTX 16xx / RTX 20xx) and newer you can try
  # the open kernel modules:  hardware.nvidia.open = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.nvidiaSettings = true;
  hardware.graphics.enable = true;
  # Required for niri/Hyprland on NVIDIA.
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];
  # Wayland compositors sometimes need these with NVIDIA; uncomment if you see
  # rendering glitches:
  # environment.sessionVariables = {
  #   LIBVA_DRIVER_NAME = "nvidia";
  #   GBM_BACKEND = "nvidia-drm";
  #   __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  # };

  # --- Networking -------------------------------------------------------------
  # Keep in sync with the flake's `hostname` variable.
  networking.hostName = "tower";
  networking.networkmanager.enable = true;

  # --- Locale / time ----------------------------------------------------------
  time.timeZone = "Asia/Jakarta"; # adjust to your location
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";

  # --- Display manager + compositors -----------------------------------------
  services.xserver.enable = true;
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # niri (primary) and Hyprland (secondary) both registered as sessions.
  programs.niri.enable = true;
  programs.hyprland.enable = true;

  # Portals: screen capture / file pickers / clipboard under Wayland.
  xdg.portal.enable = true;
  xdg.portal.wlr.enable = true; # Hyprland screencast
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # --- Audio ------------------------------------------------------------------
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- Fonts (system-wide, also used by SDDM) ---------------------------------
  fonts.packages = with pkgs; [
    iosevka-bin
    nerd-fonts.iosevka
    noto-fonts-cjk-serif
  ];

  # --- User -------------------------------------------------------------------
  users.users.pn = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "libvirtd" "video" "audio" ];
    shell = pkgs.zsh;
    # Set a password on first boot with `passwd`, or pre-seed:
    #   hashedPassword = "...";  # mkpasswd -m sha-512
  };
  programs.zsh.enable = true; # required for zsh as a login shell

  # --- System packages ---------------------------------------------------------
  # Most user-facing tools come from home-manager; keep only what the system
  # or root needs here.
  environment.systemPackages = with pkgs; [
    git
    kitty
    home-manager
    virt-manager
    podman-compose
  ];

  # --- Containers: podman (docker-compatible) ----------------------------------
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # `docker` CLI shim -> podman
    dockerSocket.enable = true; # /var/run/docker.sock for tools that expect it
  };

  # --- Virtualization: libvirt/QEMU --------------------------------------------
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # --- Nix ---------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # --- Firewall ----------------------------------------------------------------
  networking.firewall.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];

  # Fresh NixOS install; bump only when you know what stateVersion does.
  system.stateVersion = "25.05";
}
