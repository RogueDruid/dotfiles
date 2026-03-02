#!/usr/bin/env bash
# arch-wayland-migrate-to-hyprland.sh
# Detect what you have installed (X11/Wayland bits, WM/DE, display/login managers, bars/launchers)
# and provide a safe, step-by-step migration plan to Hyprland.

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

hr() { printf "\n%s\n" "============================================================"; }
sec() { hr; printf "%s\n" "$1"; hr; }

pkg_installed() {
  local p="$1"
  pacman -Q "$p" >/dev/null 2>&1
}

aur_installed() {
  # heuristic: package present but not in sync db? (works for many AUR packages too)
  pacman -Q "$1" >/dev/null 2>&1
}

print_kv() {
  local k="$1" v="$2"
  printf "%-28s %s\n" "$k:" "$v"
}

detect_session() {
  local sess="${XDG_SESSION_TYPE:-unknown}"
  local desk="${XDG_CURRENT_DESKTOP:-unknown}"
  local dg="${DESKTOP_SESSION:-unknown}"
  print_kv "XDG_SESSION_TYPE" "$sess"
  print_kv "XDG_CURRENT_DESKTOP" "$desk"
  print_kv "DESKTOP_SESSION" "$dg"
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then print_kv "WAYLAND_DISPLAY" "$WAYLAND_DISPLAY"; fi
  if [[ -n "${DISPLAY:-}" ]]; then print_kv "DISPLAY" "$DISPLAY"; fi
}

detect_gpu() {
  if have lspci; then
    sec "GPU (lspci)"
    lspci -nnk | awk '
      /VGA compatible controller|3D controller|Display controller/ {print; flag=1; next}
      flag && /Kernel driver in use|Kernel modules/ {print; next}
      flag && NF==0 {flag=0}
    '
  else
    print_kv "lspci" "not found (install pciutils)"
  fi
}

detect_login_manager() {
  sec "Display/Login manager (common services)"
  local found=0
  for svc in sddm gdm lightdm greetd lxdm; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
      print_kv "enabled" "$svc"
      found=1
    fi
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      print_kv "active" "$svc"
      found=1
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    echo "No common display manager is enabled/active (maybe you start from TTY)."
  fi
}

detect_wm_de() {
  sec "WM/DE binaries present"
  local bins=(
    Hyprland sway i3 bspwm openbox awesome
    gnome-shell plasmashell kwin_wayland kwin_x11
    weston river labwc wayfire
  )
  for b in "${bins[@]}"; do
    if have "$b"; then print_kv "found" "$b"; fi
  done
}

detect_bars_launchers() {
  sec "Bars / launchers / portals / helpers present"
  local bins=(waybar rofi wofi fuzzel dmenu bemenu
              mako dunst
              grim slurp wl-copy wl-paste cliphist
              wlogout swaylock hyprlock hypridle
              xrandr arandr
              xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-hyprland
              pipewire wireplumber
             )
  for b in "${bins[@]}"; do
    if have "$b"; then print_kv "found" "$b"; fi
  done
}

detect_packages() {
  sec "Key packages (pacman)"
  local pkgs=(
    # Wayland/Hyprland core
    hyprland hyprpaper hyprlock hypridle xdg-desktop-portal-hyprland
    # X11 stack
    xorg-server xorg-xinit xorg-xwayland xorg-xrandr xorg-xauth
    # common DMs
    sddm gdm lightdm greetd
    # audio
    pipewire wireplumber
    # bars/launchers
    waybar wofi rofi fuzzel
    # wl utils
    grim slurp wl-clipboard cliphist
  )
  for p in "${pkgs[@]}"; do
    if pkg_installed "$p"; then
      print_kv "installed" "$p"
    fi
  done
}

migration_plan() {
  sec "Migration plan to Hyprland (safe approach)"
  cat <<'EOF'
0) Do NOT remove anything yet.
   You can install Hyprland and switch sessions without uninstalling Xorg/i3/Sway.

1) Install Hyprland and essentials (Arch packages):
   sudo pacman -S hyprland xdg-desktop-portal-hyprland xorg-xwayland \
     waybar wofi wl-clipboard grim slurp pipewire wireplumber

   Notes:
   - xorg-xwayland lets old X11 apps run inside Hyprland.
   - xdg-desktop-portal-hyprland enables screen sharing/portals in many apps.

2) Create Hyprland config:
   mkdir -p ~/.config/hypr
   If /usr/share/hyprland exists, copy the default:
     cp -n /usr/share/hyprland/hyprland.conf ~/.config/hypr/hyprland.conf
   Or generate from package defaults if present on your system.

3) If you start from TTY (no display manager):
   Create a simple start entry in ~/.bash_profile or ~/.zprofile:
     if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
       exec Hyprland
     fi

   (Only do this if you want Hyprland to auto-start on tty1.)

4) If you use a display manager:
   - GDM: will show “Hyprland” as a session if the desktop file exists.
   - SDDM: should show Hyprland session; if not, install a session file.
   - greetd: configure to launch Hyprland.

5) Port i3/Sway concepts:
   - keybinds: bind = SUPER,Return,exec,alacritty (etc.)
   - workspaces: workspace = 1, monitor:... mapping etc.
   - bar: Waybar is common (works well on Hyprland)
   - notifications: mako (Wayland) instead of dunst (X11)
   - screenshots: grim + slurp
   - clipboard: wl-clipboard + cliphist
   - lock: hyprlock (or swaylock)

6) Multi-monitor:
   Use Hyprland monitor directives (NOT xrandr).
   Example:
     monitor=DP-1,1920x1080@60,0x0,1
     monitor=HDMI-A-1,1920x1080@60,1920x0,1

7) Validate portals/screen sharing:
   Ensure:
     systemctl --user status pipewire wireplumber
   and that xdg-desktop-portal services are running:
     systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland

8) Only after you are happy:
   Consider removing unused Xorg pieces (optional):
     sudo pacman -Rns xorg-server xorg-xinit ...
   Keep xorg-xwayland if you still run any X11 apps.
EOF
}

post_checks() {
  sec "Post-install checks"
  cat <<'EOF'
- Confirm you are in Wayland:
  echo $XDG_SESSION_TYPE

- See Hyprland clients and whether they are XWayland:
  hyprctl clients | sed -n '1,200p'

- Check portals (screen sharing):
  systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland

- If apps are blurry (common with mixed DPI):
  Prefer running them native Wayland when possible; otherwise tune scaling settings.
EOF
}

main() {
  sec "Current session"
  detect_session

  detect_gpu
  detect_login_manager
  detect_wm_de
  detect_bars_launchers
  detect_packages

  migration_plan
  post_checks

  sec "Done"
  echo "This script only reports and prints a plan; it does not change your system."
}

main "$@"