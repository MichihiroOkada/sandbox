alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'
#alias vi='/usr/bin/vim'
bindkey -e

#export RUBYLIB=/var/lib/gems/1.8/gems/json-1.8.1/lib
export JLESSCHARSET=japanese

export HISTFILE=${HOME}/.zsh_history
export SAVEHIST=100000
export HISTSIZE=100000
setopt hist_ignore_dups
setopt share_history
export PROMPT='[%F{red}%B%n%b%f@%F{cyan}%d%f]
%# '

#bindkey -v

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
export EDITOR=/usr/local/bin/vim

DIRSTACKSIZE=100
setopt AUTO_PUSHD

autoload -Uz compinit && compinit

zstyle ':completion:*' menu select
zstyle ':completion:*:cd:*' ignore-parents parent pwd
zstyle ':completion:*:descriptions' format '%BCompleting%b %U%d%u'

export TERM="xterm"
