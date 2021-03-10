"Pathogen
execute pathogen#infect()
"Colorscheme
syntax on
colorscheme onedark
highlight Normal ctermbg=NONE
highlight nonText ctermbg=NONE
let g:lightline = {
    \ 'colorscheme': 'dracula',
    \ }
" View Settings
set autoread
set ruler
set number relativenumber
set laststatus=2
set noshowmode
set ttimeoutlen=50
set wildmenu
set lazyredraw
" Search Settings
set hlsearch
set incsearch
set showmatch
nnoremap <silent><esc><esc> :nohlsearch<CR>
" Indenting and Tabs
set tabstop=4           " width that a <TAB> character displays as
set expandtab           " convert <TAB> key-presses to spaces
set shiftwidth=4        " number of spaces to use for each step of (auto)indent
set softtabstop=4       " backspace after pressing <TAB> will remove up to this many spaces
set autoindent          " copy indent from current line when starting a new line
set smartindent         " even better autoindent (e.g. add indent after '{')
autocmd FileType make set noexpandtab shiftwidth=8 softtabstop=0
