set nocompatible              " be iMproved, required
filetype off                  " required
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

inoremap jk <ESC>
syntax on # highlight syntax
set number
set noswapfile
set hlsearch
set ignorecase
set incsearch

" turn hybrid line numbers on
:set number relativenumber
:set nu rnu

map <F2> :NERDTreeToggle<CR>

let mapleader = ","

noremap <leader>/ :Commentary<cr>

call plug#begin()
Plug 'SirVer/ultisnips'
Plug 'tomlion/vim-solidity'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'Shougo/deoplete.nvim'
Plug 'deoplete-plugins/deoplete-go', { 'do': 'make'}
Plug 'sheerun/vim-polyglot'
Plug 'ghifarit53/tokyonight-vim'
Plug 'Yggdroot/indentLine'
Plug 'psliwka/vim-smoothie'
Plug 'mbbill/undotree'
Plug 'tpope/vim-commentary'
Plug 'preservim/nerdtree'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'ryanoasis/vim-devicons'
call plug#end()
