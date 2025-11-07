#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
export GSK_RENDERER=ngl

alias ..='cd ..'
alias cmatrix='cmatrix -C yellow'
alias off='systemctl poweroff'
alias asa='vim $(fzf --preview="bat --color=always {}")'
alias ls='ls -a --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

fastfetch --color "38;2;215;153;33"
