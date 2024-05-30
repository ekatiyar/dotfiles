# Dotfiles
My personal terminal configuration dotfiles, with easy deployment using stow. Includes:
  - [Vim](https://github.com/vim/vim) configuration. Includes [pathogen](https://github.com/tpope/vim-pathogen), [onedark](https://github.com/joshdick/onedark.vim), and [lightline](https://github.com/itchyny/lightline.vim)
  - Oh-my-zsh, with you-should-use, syntax-highlighting, and autosuggestions
  - Zoxide as a replacement for `cd` (fzf recommended but optional)

## Instructions
Run the following commands to set everything up:
1. Cd to your home directory `cd ~`
2. Use `git clone --recursive https://github.com/eashman123/dotfiles.git` in order to clone this repository, as all plugins are included as git submodules 
3. Cd into the directory `cd dotfiles/` and run `stow .`
