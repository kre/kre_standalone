# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions

PATH=$PATH:/sbin:/usr/sbin:/usr/local/bin:$HOME/bin

export PATH
unset USERNAME

export KOBJ_ROOT=/web/lib/perl
export WEB_ROOT=/web
export JAVA_HOME=/usr/lib/jvm/java-1.6.0-openjdk.x86_64

alias err="tail -f ~/logs/error_log"
alias acc="tail -f ~/logs/access_log"
alias log="tail -f /web/logs/detail_log"
alias start="sudo /etc/init.d/httpd start"
alias restart="sudo /etc/init.d/httpd restart"
alias stop="sudo /etc/init.d/httpd stop"
alias bounce="netdown;netup"
alias big="/usr/bin/xrandr -s 1920x1200"
alias restartall='(cd ~/lib/perl/parser; ./buildjava.sh);perl -MInline::Java::Server=restart;sudo /etc/init.d/httpd restart'

# Set ulimit for web user
ulimit -s 16384
