####### HTTP #######
# Args: url, params

http.info() {
  url=$1
  params=$2
  exec >&2

  [[ -n $params ]] && params="?$params"
  if have httpstat; then
    httpstat "$url$params"
  else
    curl -sI "$url$params"
  fi
}

# Example:
# If dl recieves:                https://www.google.com/search?q=example
# Then http.handlers are passed: www.google.com/search, q=example

http.gutenberg() {
	id=$1:t # https://gutenberg.org/ebooks/76257 -> 76257
	url=https://www.gutenberg.org/cache/epub/$id/pg$id-images.html
	http.default $url # downloads the url and outputs the destination filename
}

# example of customizing the input. This is safe because urls don't have spaces.
_read_url_params() {
  __read_url_params $@;
  url=${url%%" | "*}
}

_http.dl() {
  $YTDLPcmd \
	  -f "bestvideo[vcodec=av01]+bestaudio[acodec=opus]/best,bestvideo+bestaudio/best" \
	  --abort-on-unavailable-fragments \
	  --print after_move:filepath \
	  $1 ||
  $GALLERYDLcmd \
	  -D . \
	  $1
	# i have no idea what options are good
}

http.dl() {
  setopt -o pipefail
  failure_or_show _http.dl $1
}

# Downloads folders, images, or single branches of repositories from github/gitlab/huggingface. Only github is fully supported.
http.git() {
	sep="(-/|)(tree|blob)"

  # https://github.com/Squirreljetpack/fzs/tree/main/src ->
  # https://github.com/Squirreljetpack/fzs, Squirreljetpack/fzs, github.com 
  base=${${1%%/$~sep/*}#*://}
  root=${${base#*://}:h1}
  user_repo=${base#*/}

  # main/src, (/-)/tree/, 
  rest=${1#*/$~sep/}
  sep=${${1%$rest}#$base}

  if [[ -n $sep ]]; then
    ref=${${rest%%/*}%%\?*}
    subdir=${${rest#$ref}#/}
    ref_path="$(get_ref_path $ref)"
  fi

  dbginfo subdir ref

  if [[ -z $subdir || $root != github.com ]]; then
    if [[ $ref_path == refs/heads/* ]]; then
      branch=${ref_path#refs/heads/}
      info branch
      _ARGS="--branch $branch"
    else
      _ARGS=""
    fi
    _ARGS=$_ARGS ssh.clone git@$root ${user_repo%.git}.git
    return
  fi

  # incidentally, not actually necessary
  if [[ $sep == /blob/ ]]; then
    url="https://raw.githubusercontent.com/$user_repo/$ref_path/$subdir"
    http.default $url
    return
  fi

  # https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives#source-code-archive-urls
  # sparse checkout https://askubuntu.com/questions/460885/how-to-clone-only-some-directories-from-a-git-repository

  archive_url="https://$base/archive/${ref_path}.tar.gz"
  archive_root="${user_repo##*/}-$ref"
  temp_dir="$(mktemp -d)"

  info user_repo archive_url temp_dir

  # strip components=1: maps root/ -> .
  if curl -sL "$archive_url" | success_or_log tar -xzf - --directory "$temp_dir" --strip-components=1 "${archive_root}/${subdir}"; then
    read_dest file $temp_dir/${subdir} || return 0
    pere -m $temp_dir/${subdir} $dest >/dev/null
    rm -r $temp_dir
    echo $dest:t
  fi
}


####### SSH #######
# Args: userhost, subpath

ssh.info() {
  ssh -vT $1 >&2
}

# Example:
# If dl recieves:                (ssh://)user@host:path/to/file
# Then ssh.handlers are passed:  user@host:path/to/file user@host path/to/file

ssh.clone() {
	read_dest ssh $2 || return 0 # read_dest provides a valid destination path to the dest variable given the path-like component corresponding to the protocol. For ssh handlers its $2 (the subpath), but $1 for other protocol handlers.
	success_or_log git clone --single-branch ${=_ARGS} $1:$2 $dest || return # _ARGS is included to allow passing arguments to git clone when manually invoked, see http_git.
  echo $dest
}

####### FILE #######
# Args: target type mime encoding

file.walk() {
  if [[ -d $1 ]]; then
    for f in *; do
      file.walk $f
    done
  else
    handle_file $f
  fi
}

file.info() {
  file -L $1 >&2
}

file.fmt_py() {
  [[ -e ~/ruff_$FORMAT.toml ]] && opts+=(--config ~/ruff_$FORMAT.toml) || opts=()
  failure_or_show ruff format $opts $1
}

file.fmt_biome() {
  [[ -e ~/biome_$FORMAT.toml ]] && opts=(--config-path ~/biome_$FORMAT.toml) || opts=()
  failure_or_show biome format $opts $1
}

file.fmt_sh() {
  failure_or_show shfmt -w $1
}


####### HELPER FUNCTIONS

get_ref_path() {
  [[ -z $1 ]] && return 1
  if [[ $1 =~ '^[0-9a-f]{40}$' ]]; then
    echo "refs/$1"
  else
    case $1 in
      [0-9]*|v*) echo "refs/tags/$1" ;;
      *)         echo "refs/heads/$1" ;;
    esac
  fi
}