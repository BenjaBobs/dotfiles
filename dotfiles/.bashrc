#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls -AF --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# fnm
FNM_PATH="/home/bh/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi
