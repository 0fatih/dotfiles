set nocompatible
filetype off
set showcmd

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" add all your plugins here (note older versions of Vundle
" used Bundle instead of Plugin)

" ...

" All of your Plugins must be added before the following line
call vundle#end()
filetype plugin indent on

" Ust kisim vundle'a ait

set encoding=utf-8
set clipboard=unnamed
set nu




Plugin 'tmhedberg/SimpylFold'
Plugin 'vim-scripts/indentpython.vim'
Plugin 'jnurmine/Zenburn'
Plugin 'altercation/vim-colors-solarized'
Plugin 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}
Plugin 'vim-syntastic/syntastic'
Plugin 'scrooloose/nerdtree'
Plugin 'kien/ctrlp.vim'
Plugin 'tpope/vim-fugitive'
Bundle 'Valloric/YouCompleteMe'


au BufNewFile, BufRead *.py
    \ set tabstop=4	  |
    \ set softtabstop=4   |
    \ set shiftwidth=4    |
    \ set textwidth=79    |
    \ set expandtab 	  |
    \ set autoindent 	  |
    \ set fileformat=unix 

au BufNewFile, BufRead *.js, *.html, *.css
    \ set tabstop=2	  |
    \ set softtabstop=2	  |
    \ set shiftwidth=2    

au BufRead, BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/


let g:ycm_autoclose_preview_window_after_completion=1
map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

let python_highlight_all=1
syntax on

let NERDTreeIgnore=['\.pyc$', '\~$'] "ignore files in NERDTree


if has('gui_running')
  set background=dark
  colorscheme solarized
else
  colorscheme zenburn
endif


call togglebg#map("<F5>")


nnoremap <F3> : NERDTreeToggle<CR>
