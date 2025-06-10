#!/bin/zsh

: ${JDL_STATE_DIR:=$HOME/.local/state/zsh-dl/}
: ${JDL_INSTALL_DIR:=$HOME/.local/bin}

[[ :$PATH: == *:$JDL_INSTALL_DIR:* ]] || $JDL_INSTALL_DIR=/usr/bin

: ${JDL_CONFIG_DIR:=$HOME/.config/zsh-dl}

for f in zsh-dl/*; do
  mktarget -c $f $JDL_CONFIG_DIR/ >/dev/null
done

print -n -- "What name should jdl be installed to?: (dl)"
read -r name
: ${name:=dl}
mktarget -c $f $JDL_INSTALL_DIR/$name >/dev/null

echo "Installation complete!" 
echo "Try $name https://github.com/Squirreljetpack/jdl/zsh-dl, to download a github folder to your current directory, or $name https://gutenberg.org/ebooks/18328 to download a book as markdown! (JohannesKaufmann/html-to-markdown is required)"