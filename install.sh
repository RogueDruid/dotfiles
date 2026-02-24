#!/bin/bash

update_links() {
    echo "Updating dotfile symlinks..."

    ln -sf ~/dotfiles/environment/theme.conf ~/.config/environment.d/theme.conf
    ln -sf ~/dotfiles/waybar ~/.config/
    ln -sf ~/dotfiles/wofi ~/.config/
    # ln -sf ~/dotfiles/profile/.profile ~/.profile
    ln -sf ~/dotfiles/hypr ~/.config/
    ln -sf ~/dotfiles/rofi ~/.config/
    # ln -sf ~/dotfiles/zsh/.zprofile ~/.zprofile
    ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
    ln -sf ~/dotfiles/ghostty ~/.config/
    ln -sf ~/dotfiles/starship/starship.toml ~/.config/starship.toml
    ln -sf ~/dotfiles/fontconfig/fonts.conf ~/.config/fontconfig/fonts.conf
    ln -sf ~/dotfiles/nvim/ ~/.config/nvim
    echo "Symlinks updated."
}

install_zsh() {
    echo "Installing zsh plugins..."

    local base_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

    install_plugin \
        "https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "$base_dir/zsh-syntax-highlighting"

    install_plugin \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        "$base_dir/zsh-autosuggestions"

    install_plugin \
        "https://github.com/zsh-users/zsh-completions.git" \
        "$base_dir/zsh-completions"

    install_plugin \
        "https://github.com/zsh-users/zsh-history-substring-search" \
        "$base_dir/zsh-history-substring-search"



    echo "Done."
}

install_all() {
    update_links
    install_zsh
}

show_menu() {
    clear
    echo "=============================="
    echo "   Dotfiles Setup Manager"
    echo "=============================="
    echo "1) Update symlinks"
    echo "2) Install zsh plugin"
    echo "3) Install everything"
    echo "4) Exit"
    echo ""
}

install_plugin() {
    local repo_url="$1"
    local target_dir="$2"

    if [ -d "$target_dir/.git" ]; then
        echo "🔄 Updating $(basename "$target_dir")..."
        git -C "$target_dir" pull --ff-only
    elif [ -d "$target_dir" ]; then
        echo "⚠️  $target_dir exists but is not a git repo. Skipping."
    else
        echo "⬇️  Cloning $(basename "$target_dir")..."
        git clone "$repo_url" "$target_dir"
    fi
}

while true; do
    show_menu
    read -p "Select an option [1-4]: " choice

    case $choice in
        1)
            update_links
            read -p "Press enter to continue..."
            ;;
        2)
            install_zsh
            read -p "Press enter to continue..."
            ;;
        3)
            install_all
            read -p "Press enter to continue..."
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
done