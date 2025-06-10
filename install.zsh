#!/bin/zsh

: ${ZSHDL_STATE_DIR:=$HOME/.local/state/zsh-dl/}
: ${ZSHDL_INSTALL_DIR:=$HOME/.local/bin}

[[ :$PATH: == *:$ZSHDL_INSTALL_DIR:* ]] || $ZSHDL_INSTALL_DIR=/usr/bin

: ${ZSHDL_CONFIG_DIR:=$HOME/.config/zsh-dl}

for f in zsh-dl/*; do
  mktarget -c $f $ZSHDL_CONFIG_DIR/ >/dev/null
done

print -n -- "What name should ZSHDL be installed to?: (dl)"
read -r name
: ${name:=dl}
mktarget -c $f $ZSHDL_INSTALL_DIR/$name >/dev/null

echo "Installation complete!" 
echo "Try $name https://github.com/Squirreljetpack/ZSHDL/tree/zsh-dl, to download a github folder to your current directory, or $name https://gutenberg.org/ebooks/18328 to download a book as markdown! (JohannesKaufmann/html-to-markdown is required)"