#!/usr/bin/env zsh

set -e

: ${ZSHDL_STATE_DIR:=$HOME/.local/state/zsh-dl/}

if [[ -z $ZSHDL_INSTALL_DIR ]]; then
	[[ :$PATH: == *:$HOME/.local/bin:* ]] &&
		ZSHDL_INSTALL_DIR=$HOME/.local/bin ||
		ZSHDL_INSTALL_DIR=/usr/bin
fi

: ${ZSHDL_CONFIG_DIR:=$HOME/.config/zsh-dl}

SCRIPT="$(readlink -f -- "$0")"
cd $SCRIPT:h || exit 1
mkdir -p $ZSHDL_CONFIG_DIR

have() {
	(( $+commands[${1%% *}] ))
}

if have pere; then
	cmd=(pere -c)
else
	cmd=(cp -ar)
fi

for f in config/*; do
	$cmd $f $ZSHDL_CONFIG_DIR/ >/dev/null
done

print -n -- "What name should zsh-dl be installed to?: (dl)"
read -r name
: ${name:=dl}

chmod +x zsh-dl
$cmd zsh-dl $ZSHDL_INSTALL_DIR/$name >/dev/null

echo "Installation complete!"
echo "Try $name https://github.com/Squirreljetpack/ZSHDL/tree/zsh-dl, to download a github folder to your current directory, or $name https://gutenberg.org/ebooks/18328 to download a book as markdown! (JohannesKaufmann/html-to-markdown is required)"
