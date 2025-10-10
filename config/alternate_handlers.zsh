http.comics() {
  local parent=~/Downloads/auto line=
  log_stderr _comics_impl $1 | {
    read -r line
  }
  [[ -n $line ]] && echo ${line:h}.cbz
}

_comics_impl() {
  gallery-dl --cbz \
    -d $parent \
    -f "{num:>04}_{filename}.{extension}" \
    "https://$1" >&2
}