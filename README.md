# Dotfiles
My personal terminal configuration dotfiles, with easy deployment using stow. Includes:
  - [Vim](https://github.com/vim/vim) configuration. Includes [pathogen](https://github.com/tpope/vim-pathogen), [onedark](https://github.com/joshdick/onedark.vim), and [lightline](https://github.com/itchyny/lightline.vim)
  - [Oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh), with [you-should-use](https://github.com/MichaelAquilina/zsh-you-should-use), [syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions). Oh-my-zsh also configured with plugins for git and [ripgrep](https://github.com/BurntSushi/ripgrep)
  - [Zoxide](https://github.com/ajeetdsouza/zoxide) as a replacement for `cd` ([fzf](https://github.com/junegunn/fzf) recommended but optional)

## Instructions
Run the following commands to set everything up:
1. Cd to your home directory `cd ~`
2. Use `git clone --recursive https://github.com/eashman123/dotfiles.git` in order to clone this repository, as all plugins are included as git submodules 
3. Cd into the directory `cd dotfiles/` and run `stow .`
