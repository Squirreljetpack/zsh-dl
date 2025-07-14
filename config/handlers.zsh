####### HTTP #######
# Args: url, params

http.info() {
  url=$1
  params=$2
  [[ -n $params ]] && params="?$params" # alternatively, just use $TARGET for the original line, see below

  exec >&2
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

# example of modifying the input arguments for http handlers. (This is safe as is because urls don't have spaces). See dl -vh for definition.
_read_url_params() {
  __read_url_params $@;
  url=${url%%" | "*}
}

http.ytdlp() {
  # yt-dlp can exit 1 even on successful download so we just rely on the output
  # Unfortunately is no way to show progress with :filepath, but -v can give some indication
  ((VERBOSE > 1)) && ARGS+=(-v)

  log_stderr $YTDLPcmd \
    -f "bestvideo[vcodec=av01]+bestaudio[acodec=opus]/best,bestvideo+bestaudio/best" \
    --abort-on-unavailable-fragments \
    --print after_move:filepath \
    -o "%(title)s.%(ext)s" \
    $ARGS \
    $TARGET
}

http.images() {
  failure_or_show $=IMAGESDLcmd $ARGS $TARGET
}

http.ytdlp_audio() {
  ((VERBOSE > 1)) && ARGS+=(-v)

  log_stderr $YTDLPcmd \
    -f "bestaudio/best" \
    -ciw \
    --extract-audio \
    --audio-format opus \
    --print after_move:filepath \
    -o "%(title)s.%(ext)s" \
    $ARGS \
    $TARGET
}

# Example of fallback to image download if no video present i.e. reddit posts
http.dl() {
  failure_or_show http.ytdlp $@ ||
  failure_or_show http.images $@
}


# Downloads folders, images, or single branches of repositories from
# github/gitlab/huggingface. Only github is fully supported.
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

  dbgvar subdir ref

  if [[ -z $subdir || $root != github.com ]]; then
    if [[ $ref_path == refs/heads/* ]]; then
      branch=${ref_path#refs/heads/}
      infovar branch
      args+=(--branch $branch)
    fi
    ssh.clone git@$root ${user_repo%.git}.git
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

  infovar user_repo archive_url temp_dir

  # strip components=1: maps root/ -> .
  if curl -sL "$archive_url" | success_or_log tar -xzf - --directory "$temp_dir" --strip-components=1 "${archive_root}/${subdir}"; then
    read_dest file $temp_dir/${subdir} || return 0
    lt -m $temp_dir/${subdir} $dest >/dev/null
    rm -r $temp_dir
    echo $dest:t
  fi
}


####### SSH #######
# Args: userhost, subpath

ssh.info() {
  ssh -vT $1 >&2
}

ssh.clone() {
  read_dest ssh $2 || return 0 # read_dest provides a valid destination path to the dest variable given the path-like component corresponding to the protocol. For ssh handlers its $2 (the subpath), but $1 for other protocol handlers.

  success_or_log git clone $ARGS --single-branch $1:$2 $dest || return
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
  echo $1
}

file.fmt_py() {
  [[ -e ~/ruff_$FORMAT.toml ]] && ARGS+=(--config ~/ruff_$FORMAT.toml)
  failure_or_show ruff format $ARGS $1
}

file.fmt_biome() {
  [[ -e ~/biome_$FORMAT.toml ]] && ARGS+=(--config-path ~/biome_$FORMAT.toml)
  failure_or_show biome format $ARGS $1
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