#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to install packages if not already installed
install_package() {
  if ! command_exists "$1"; then
    echo "Installing $1..."
    apt install -y "$1"
  else
    echo "$1 is already installed. Skipping..."
  fi
}

# Install zsh
install_package zsh

# Install zoxide
install_package zoxide

# Install fzf
install_package fzf

# Install tealdeer
install_package tealdeer

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

