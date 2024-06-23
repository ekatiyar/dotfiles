#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install packages if not already installed
install_package() {
  local package_name=$1
  local command_name=${2:-$1}  # Use the second argument as command name (in case of alias), default to package name
  local custom_install_cmd=${3:-"apt install -y $package_name"}  # Default install command can be overridden

  if ! command_exists "$command_name"; then
    echo "Installing $package_name..."
    if [ "$(id -u)" -eq 0 ]; then
      $custom_install_cmd
    else
      sudo $custom_install_cmd
    fi
  else
    echo "$package_name is already installed. Skipping..."
  fi
}

# update packages
sudo apt update

# Install Rust
install_package rustc rustc "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && source $HOME/.cargo/env"

# Install stow
install_package stow

# Install zsh
install_package zsh

# Install ripgrep
install_package ripgrep rg

# Install zoxide
install_package zoxide

# Install fzf
install_package fzf

# Install tealdeer
install_package tealdeer tldr "cargo install tealdeer"

# Check if Oh My Zsh is installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  # Install oh-my-zsh if not installed
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "Oh My Zsh is already installed. Skipping..."
fi

# Adopt dotfiles using stow, excluding the setup script
echo "Symlinking dotfiles..."
stow --adopt .

# Print message
echo "Please check for any changed files in dotfiles/ and accept/reject changes."

