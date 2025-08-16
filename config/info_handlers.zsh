####### HTTP #######

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

# also, gh repo view "https://github.com/user/repo" --json diskUsage,forkCount,url
http.git_info() {
  have tokei || {
    http.info $@
    return
  }
  sep="(-/|)(tree|blob)"

  base=${${1%%/$~sep/*}#*://}
  root=${${base#*://}:h1}
  user_repo=${base#*/}
  [[ $user_repo == */* ]] || return

  out="$(mktemp -d)"

  (($#ARGS)) || ARGS=(--depth 1) 

  success_or_log git clone $ARGS https://$root/${user_repo%.git} $out || return
  {
    cd $out
    tokei
    have du && du -d 1 -h
  } >&2
}

####### SSH #######

ssh.info() {
  ssh -vT $1 >&2
}

####### FILE #######

file.info() {
  {
    if [[ -d $1 ]]; then
      have du && du -d 1 -h $1
    else
      file -L $1
    fi
  } >&2
}