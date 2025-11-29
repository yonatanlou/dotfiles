# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# Example aliases
alias -g zshconf="open ~/.zshrc"


source $ZSH/oh-my-zsh.sh

alias cursor="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
alias zrc='subl ~/.zshrc'
alias src='source ~/.zshrc'
alias claude-commands='subl ~/.claude/commands'
export PATH="$HOME/.local/bin:$PATH"



## python env stuff
alias mkvenv='python3.11 -m venv .venv && source .venv/bin/activate'
acvenv() {
    if [ -f "./bin/activate" ]; then
        source ./bin/activate
    elif [ -f "./.venv/bin/activate" ]; then
        source ./.venv/bin/activate
    else
        echo "No activation script found in this folder."
    fi
}

