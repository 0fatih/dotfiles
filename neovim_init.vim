filetype on
filetype plugin on
filetype indent on

syntax on

set clipboard=unnamedplus
set encoding=UTF-8
set nocompatible 
set autoindent
set smartindent
set number
set relativenumber
set mouse=a
set cursorline
set shiftwidth=2
set tabstop=2
set expandtab
set nobackup
set scrolloff=10
set nowrap
set incsearch
set ignorecase
set smartcase
set showcmd
set showmode
set showmatch
set hlsearch
set history=1000
set wildmenu
set wildmode=list:longest
set wildignore=*.docx,*.jpg,*.png,*.gif,*.pdf,*.pyc,*.exe,*.flv,*.img,*.xlsx
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

let g:delimitMate_expand_cr = 2

colorscheme molokai 

" PLUGINS ---------------------------------------------------------------- {{{

" Plugin code goes here.
call plug#begin('~/.vim/plugged')

" HTML Tags
Plug 'alvan/vim-closetag'

" Comment
Plug 'tpope/vim-commentary'

"" Language supports

Plug 'neoclide/coc.nvim', {'branch': 'release'}

Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

"Plug 'neovim/nvim-lspconfig'
"Plug 'hrsh7th/nvim-compe'

"let g:compe                  = {}
"let g:compe.autocomplete     = v:true
"let g:compe.debug            = v:false
"let g:compe.documentation    = v:true
"let g:compe.enabled          = v:true
"let g:compe.incomplete_delay = 400
"let g:compe.max_abbr_width   = 80
"let g:compe.max_kind_width   = 80
"let g:compe.max_menu_width   = 80
"let g:compe.min_length       = 1
"let g:compe.preselect        = 'enable'
"let g:compe.resolve_timeout  = 800
"let g:compe.source           = {}
"let g:compe.source.buffer    = v:true
"let g:compe.source.calc      = v:true
"let g:compe.source.emoji     = v:false
"let g:compe.source.luasnip   = v:false
"let g:compe.source.nvim_lsp  = v:true
"let g:compe.source.nvim_lua  = v:true
"let g:compe.source.path      = v:true
"let g:compe.source.ultisnips = v:false
"let g:compe.source.vsnip     = v:false
"let g:compe.source_timeout   = 200
"let g:compe.throttle_time    = 10

"Nerdtree and it's plugins"
Plug 'preservim/nerdtree'
Plug 'ryanoasis/vim-devicons'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
"Nerdtree and it's plugins"

"For theme"
"Plug 'mhartington/oceanic-next'
Plug 'morhetz/gruvbox'
autocmd vimenter * ++nested colorscheme gruvbox
"For theme"

"Good for commenting"
Plug 'scrooloose/nerdcommenter'
"Good for commenting"

" For statusline"
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
" For statusline"

"Github extension"
Plug 'tpope/vim-fugitive'
"Github extension"

"Some cool shortcuts
Plug 'tpope/vim-rsi'

"wrapping is way easier with this plugin"
Plug 'tpope/vim-surround'
"wrapping is way easier with this plugin"

" Awesome for finding somethings
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
" Awesome for finding somethings

" Auto complete paranthesis
Plug 'Raimondi/delimitMate'
" Auto complete paranthesis

Plug 'wellle/targets.vim'

"For languages 
Plug 'tomlion/vim-solidity'
Plug 'pangloss/vim-javascript'
Plug 'mxw/vim-jsx'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'rust-lang/rust.vim'
Plug 'ap/vim-css-color'
"For languages 


call plug#end()

" }}}


" MAPPINGS --------------------------------------------------------------- {{{

" Mappings code goes here.

inoremap jj <esc>

nnoremap <leader>\ :noh

nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

nnoremap <silent> <c-Up> :resize -1<CR>
nnoremap <silent> <c-Down> :resize +1<CR>
nnoremap <silent> <c-left> :vertical resize -1<CR>
nnoremap <silent> <c-right> :vertical resize +1<CR>

nnoremap <F3> :NERDTreeToggle<cr>

nnoremap <c-p> :Files<CR>
" }}}


" VIMSCRIPT -------------------------------------------------------------- {{{

" This will enable code folding.
" Use the marker method of folding.
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
augroup END
autocmd Filetype html setlocal tabstop=2 shiftwidth=2 expandtab
if version >= 703
    set undodir=~/.vim/backup
    set undofile
    set undoreload=10000
endif


" More Vimscripts code goes here.

" }}}


" STATUS LINE ------------------------------------------------------------ {{{

" Status bar code goes here.

set statusline=

set statusline+=\ %F\ %M\ %Y\ %R
set statusline+=%=

set statusline+=\ col:\ %c\ percent:\ %p%%
set laststatus=2
" }}}

let g:airline_theme="luna"
