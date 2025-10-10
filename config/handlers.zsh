####### HTTP #######
# Args: url, params

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
  # metadata=(--embed-metadata --embed-thumbnail)

  log_stderr yt-dlp \
    -f "bestvideo[vcodec=av01]+bestaudio[acodec=opus]/best[ext=webm] / bv*+ba/b" \
    --abort-on-unavailable-fragments \
    --cookies-from-browser $BROWSER \
    --print after_move:filepath \
    -o "%(title)s.%(ext)s" \
    $ARGS \
    $TARGET |
    awk '!seen[$0]++'
}

http.ytdlp_audio() {
  ((VERBOSE > 1)) && ARGS+=(-v)
  # metadata=(--embed-metadata --embed-thumbnail)

  log_stderr yt-dlp \
    -f "bestaudio/wv+bestaudio[acodec=opus]/best" \
    -ciw \
    --extract-audio \
    --audio-format opus \
    --cookies-from-browser $BROWSER \
    --print after_move:filepath \
    -o "%(title)s.%(ext)s" \
    $ARGS \
    $TARGET |
    awk '!seen[$0]++'
}

http.images_flat() {
  # download to current directory
  show_or_fail gallery-dl -D . $ARGS $TARGET
}

# download single files directly and multiple files to a directory
http.images() {
  set -o local_options
  local dest=$1:t first= line= second=false
  
  log_stderr gallery-dl -D $dest $ARGS $TARGET | {
    while read -r line; do
      [[ -n $line ]] || continue
      [[ -z $first ]] && first=$line && second=true && continue
      $second && echo $first && second=false
      echo $line
    done
  }

  if $second && [[ -n $first ]]; then
    local fdest=${first#*/}
    mv $first $fdest && echo $fdest
    local files=($dest/*(ND))
    (( $#files == 0 )) && rm -r $dest || warn "Preserved $dest due to files remaining"
  fi 
}

# Example of fallback to image download if no video present i.e. reddit posts
http.dl() {
  show_or_fail http.ytdlp $@ ||
  show_or_fail http.images $@
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
  [[ $user_repo == */* ]] || return

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
      ARGS+=(--branch $branch)
    fi
    ssh.clone git@$root ${user_repo%.git}.git || {
      read_dest file $user_repo || return 0
      success_or_log git clone $ARGS https://$root/$user_repo $dest || return
      echo $dest
    }
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
  else
    return 1
  fi
}


####### SSH #######
# Args: userhost, subpath

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

file.fmt_py() {
  [[ -e ~/ruff_$FORMAT.toml ]] && ARGS+=(--config ~/ruff_$FORMAT.toml)
  show_or_fail ruff format $ARGS $1
}

file.fmt_biome() {
  [[ -e ~/biome_$FORMAT.toml ]] && ARGS+=(--config-path ~/biome_$FORMAT.toml)
  show_or_fail biome format $ARGS $1
}

file.fmt_sh() {
  show_or_fail shfmt -w -l -s $1
}

# this example demonstrates how matching can be done on any of the
# handler inputs, as well as how to fall back to the default handler
file.link_handler() {
  if [[ $1 == /ARCHIVE/* || "$(readlink $1)" == /ARCHIVE/* ]]; then
    file.default $@ # see my post https://chasingsunlight.netlify.app/posts/distributed-dropbox-with-syncthing/ for one way this handler could be used.
  else
    file.default $@
  fi
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