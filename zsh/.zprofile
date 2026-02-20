# Auto-launch Hyprland on TTY1 login
if [ "$(tty)" = "/dev/tty1" ]; then
    read -p "Start Hyprland? [y]es or [n]o: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        exec start-hyprland
    fi
fi