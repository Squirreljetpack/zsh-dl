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
  ((VERBOSE > 1)) && ARGS+=(-v)
  # ARGS+=(--embed-metadata --embed-thumbnail)
  temp_file="$(mktemp)"

  log_stderr yt-dlp \
    -f "bestvideo[vcodec=av01]+bestaudio[acodec=opus]/best[ext=webm] / bv*+ba/b" \
    --abort-on-unavailable-fragments \
    --cookies-from-browser $BROWSER \
    --print-to-file after_move:filepath $temp_file \
    # -o "%(title)s.%(ext)s" \
    -o "%(playlist_title&{}|.)s/%(title)s.%(ext)s" \
    $ARGS \
    $TARGET >&2

    awk '!seen[$0]++' $temp_file
}

http.ytdlp_audio() {
  ((VERBOSE > 1)) && ARGS+=(-v)
  temp_file="$(mktemp)"
  # ARGS+=(--embed-metadata --embed-thumbnail)

  log_stderr yt-dlp \
    -f "bestaudio/wv+bestaudio[acodec=opus]/best" \
    -ciw \
    --extract-audio \
    --audio-format opus \
    --cookies-from-browser $BROWSER \
    --print-to-file after_move:filepath $temp_file \
    -o "%(playlist_title&{}|.)s/%(title)s.%(ext)s" \
    $ARGS \
    $TARGET >&2

    awk '!seen[$0]++' $temp_file
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
      success_or_log git clone --single-branch --filter=blob:none $ARGS https://$root/$user_repo $dest || return
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


# Downloads the source distribution of a PyPI package.
# Handles https://pypi.org/project/<pkg>/<version>/ or without a version (latest).
http.pypi() {
  local url="$1"

  # Parse package name and optional version
  local path_part="${${url#*pypi.org/project/}%/}"
  local pkg="${path_part%%/*}"
  local version=""
  [[ "$path_part" == *"/"* ]] && version="${path_part#*/}"

  # Fetch release metadata via PyPI JSON API
  local json="$(curl -sfL "https://pypi.org/pypi/${pkg}/${version:+${version}/}json")"
  [[ -z "$json" ]] && return 1

  # Extract exact version and sdist (source distribution) tarball URL
  local meta=($(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
ver = data['info']['version']
url = next((u['url'] for u in data['urls'] if u['packagetype'] == 'sdist'), '')
print(f'{ver} {url}')
" "$json"))

  local resolved_ver="${meta[1]}"
  local sdist_url="${meta[2]}"
  [[ -z "$sdist_url" ]] && return 1

  local downloaded_folder="${pkg}-${resolved_ver}"
  read_dest file "$downloaded_folder" || return 0

  local temp_archive="$(mktemp /tmp/pypi.XXXXXX)"

  success_or_log curl -sfL -H "User-Agent: zsh-dl" "$sdist_url" -o "$temp_archive" || {
    local code=$?
    rm -f "$temp_archive"
    return $code
  }

  mkdir -p "$dest"

  # Unpack based on file extension (.tar.gz vs .zip)
  if [[ "$sdist_url" == *.zip ]]; then
    success_or_log unzip -q "$temp_archive" -d "$dest" || { local code=$?; rm -f "$temp_archive"; return $code; }
  else
    success_or_log tar -xf "$temp_archive" -C "$dest" --strip-components=1 || { local code=$?; rm -f "$temp_archive"; return $code; }
  fi

  rm -f "$temp_archive"
  echo "$dest"
}


# Downloads the source of a Homebrew formula.
# Handles https://formulae.brew.sh/formula/<name>.
http.homebrew() {
  local url="$1"
  local formula="${${url#*formulae.brew.sh/formula/}%%[/?#]*}"

  # Query Homebrew API for formula source URL and stable version
  local json="$(curl -sfL "https://formulae.brew.sh/api/formula/${formula}.json")"
  [[ -z "$json" ]] && return 1

  local meta=($(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
ver = data['versions']['stable']
url = data['urls']['stable']['url']
print(f'{ver} {url}')
" "$json"))

  local version="${meta[1]}"
  local src_url="${meta[2]}"
  [[ -z "$src_url" ]] && return 1

  local downloaded_folder="${formula}-${version}"
  read_dest file "$downloaded_folder" || return 0

  local temp_archive="$(mktemp /tmp/brew.XXXXXX)"

  success_or_log curl -sfL -H "User-Agent: zsh-dl" "$src_url" -o "$temp_archive" || {
    local code=$?
    rm -f "$temp_archive"
    return $code
  }

  mkdir -p "$dest"

  if [[ "$src_url" == *.zip ]]; then
    success_or_log unzip -q "$temp_archive" -d "$dest" || { local code=$?; rm -f "$temp_archive"; return $code; }
  else
    success_or_log tar -xf "$temp_archive" -C "$dest" --strip-components=1 || { local code=$?; rm -f "$temp_archive"; return $code; }
  fi

  rm -f "$temp_archive"
  echo "$dest"
}


# Downloads the source tarball of an npm package.
# Handles https://www.npmjs.com/package/<pkg>[/v/<version>], incl. scoped packages.
http.npmjs() {
  local url="$1"
  local path_part="${${url#*npmjs.com/package/}%/}"

  local pkg="" version=""
  if [[ "$path_part" == *"/v/"* ]]; then
    pkg="${path_part%%/v/*}"
    version="${path_part#*/v/}"
  else
    pkg="$path_part"
  fi

  # URL-encode scoped packages (e.g., @scope/pkg -> @scope%2Fpkg)
  local encoded_pkg="${pkg/\//%2F}"
  local json="$(curl -sfL "https://registry.npmjs.org/${encoded_pkg}/${version:-latest}")"
  [[ -z "$json" ]] && return 1

  local meta=($(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
ver = data['version']
url = data['dist']['tarball']
print(f'{ver} {url}')
" "$json"))

  local resolved_ver="${meta[1]}"
  local tarball_url="${meta[2]}"

  # Remove scope prefix for folder name if present
  local clean_name="${pkg:t}"
  local downloaded_folder="${clean_name}-${resolved_ver}"
  read_dest file "$downloaded_folder" || return 0

  local temp_tgz="$(mktemp /tmp/npm.XXXXXX.tgz)"

  success_or_log curl -sfL -H "User-Agent: zsh-dl" "$tarball_url" -o "$temp_tgz" || {
    local code=$?
    rm -f "$temp_tgz"
    return $code
  }

  mkdir -p "$dest"
  # npm tarballs store root contents under package/, so --strip-components=1 flattens it
  success_or_log tar -xzf "$temp_tgz" -C "$dest" --strip-components=1 || {
    local code=$?
    rm -f "$temp_tgz"
    return $code
  }

  rm -f "$temp_tgz"
  echo "$dest"
}


# Downloads the source of a crates.io crate.
# Handles https://crates.io/crates/<name>/<version>.
http.crates_io() {
  local url="$1"

  # Parse crate name and version from URL (e.g. .../crates/ring/0.17.13)
  local path_part="${url#*crates.io/crates/}"
  local crate="${path_part%%/*}"
  local version="${${path_part#*/}%%[/?#]*}"

  local downloaded_folder="${crate}-${version}"

  read_dest file "$downloaded_folder" || return 0

  local download_url="https://crates.io/api/v1/crates/${crate}/${version}/download"
  local temp_crate="$(mktemp /tmp/crate.XXXXXX.tar.gz)"

  # Download archive
  success_or_log curl -sfL -H "User-Agent: zsh-dl" "$download_url" -o "$temp_crate" || {
    local code=$?
    rm -f "$temp_crate"
    return $code
  }

  # Extract source files into $dest
  mkdir -p "$dest"
  success_or_log tar -xzf "$temp_crate" -C "$dest" --strip-components=1 || {
    local code=$?
    rm -f "$temp_crate"
    return $code
  }

  rm -f "$temp_crate"

  # Only output final directory path
  echo "$dest"
}


# Downloads the source of a Go module from proxy.golang.org.
# Handles https://pkg.go.dev/<module>[/sub/package][?tab=...].
# Walks up subpackage paths to find the module root (proxy 404s non-modules).
http.golang() {
  local url="$1"
  local module="${url#*pkg.go.dev/}"
  module="${module%%\?*}"
  module="${module%%\#*}"

  # Find the module root: try the full path, pop a segment on failure.
  local version=""
  while [[ -n "$module" ]]; do
    local latest="$(curl -sfL "https://proxy.golang.org/${module}/@latest" 2>/dev/null)"
    if [[ -n "$latest" ]]; then
      version="$(printf '%s' "$latest" | python3 -c "import sys,json;print(json.load(sys.stdin)['Version'])" 2>/dev/null)"
      break
    fi
    module="${module%/*}"
  done
  [[ -z "$version" ]] && return 1

  local downloaded_folder="${module:t}-${version}"
  read_dest file "$downloaded_folder" || return 0

  local temp_zip="$(mktemp /tmp/golang.XXXXXX.zip)"
  success_or_log curl -sfL "https://proxy.golang.org/${module}/@v/${version}.zip" -o "$temp_zip" || {
    local code=$?
    rm -f "$temp_zip"
    return $code
  }

  # Zip contains a single root dir "<module>@<version>/"; flatten it.
  local root="$(unzip -Z1 "$temp_zip" 2>/dev/null | head -n1)"
  root="${root%/}"
  local temp_dir="$(mktemp -d)"
  success_or_log unzip -q "$temp_zip" -d "$temp_dir" || { local code=$?; rm -rf "$temp_dir" "$temp_zip"; return $code; }

  mkdir -p "$dest"
  mv "$temp_dir/$root"/* "$dest"/
  rm -rf "$temp_dir" "$temp_zip"
  echo "$dest"
}


# Downloads the source of a Debian package via sources.debian.org + the deb pool.
# Handles https://sources.debian.org/src/<pkg>[/<version>].
http.debian() {
  local url="$1"
  local pkg="${${url#*sources.debian.org/src/}%%[/?#]*}"

  local json="$(curl -sfL "https://sources.debian.org/api/src/${pkg}/")"
  [[ -z "$json" ]] && return 1

  local meta=($(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
# newest version that isn't experimental-only
for v in data['versions']:
    if 'experimental' in v['suites'] and len(v['suites']) == 1:
        continue
    ver = v['version']
    area = v['area']
    print(f'{ver} {area}')
    break
" "$json"))

  local version="${meta[1]}"
  local area="${meta[2]}"
  [[ -z "$version" ]] && return 1

  local letter="${pkg[1]}"
  [[ "$pkg" == lib* ]] && letter="lib${pkg[4]}"
  local pool="https://deb.debian.org/debian/pool/${area}/${letter}/${pkg}"

  local temp_dsc="$(mktemp /tmp/deb.XXXXXX)"
  success_or_log curl -sfL "${pool}/${pkg}_${version}.dsc" -o "$temp_dsc" || { local code=$?; rm -f "$temp_dsc"; return $code; }

  # Prefer the upstream tarball from the dsc Files block, else a native .tar.*
  local src_tar="$(grep -oE '[^ ]+\.orig\.tar\.(gz|xz|bz2|lzma|Z)$' "$temp_dsc" | head -n1)"
  [[ -z "$src_tar" ]] && src_tar="$(grep -oE "${pkg}_${version}\.tar\.(gz|xz|bz2|lzma)$" "$temp_dsc" | head -n1)"
  rm -f "$temp_dsc"
  [[ -z "$src_tar" ]] && return 1

  local downloaded_folder="${pkg}-${version}"
  read_dest file "$downloaded_folder" || return 0

  local temp_archive="$(mktemp /tmp/deb.XXXXXX)"
  success_or_log curl -sfL "${pool}/${src_tar}" -o "$temp_archive" || { local code=$?; rm -f "$temp_archive"; return $code; }

  mkdir -p "$dest"
  success_or_log tar -xf "$temp_archive" -C "$dest" --strip-components=1 || { local code=$?; rm -f "$temp_archive"; return $code; }
  rm -f "$temp_archive"
  echo "$dest"
}


# Downloads the source of an Ubuntu package.
# Handles https://launchpad.net/ubuntu/+source/<pkg> or
# https://packages.ubuntu.com/<series>/<pkg> / .../source/<series>/<pkg>.
http.ubuntu() {
  local url="$1"
  local series="noble" pkg=""

  if [[ "$url" == *launchpad.net* ]]; then
    pkg="${${url#*+source/}%%[/?#]*}"
  elif [[ "$url" == *packages.ubuntu.com* ]]; then
    local rest="${url#*packages.ubuntu.com/}"
    rest="${rest%%\?*}"
    local parts=("${(@s:/:)rest}")
    if (( $#parts == 1 )); then
      pkg="${parts[1]}"
    elif [[ "${parts[1]}" == source ]]; then
      series="${parts[2]}"; pkg="${parts[3]}"
    else
      series="${parts[1]}"; pkg="${parts[2]}"
    fi
  else
    return 1
  fi
  [[ -z "$pkg" ]] && return 1

  # Resolve the published source version via Launchpad.
  local api="https://api.launchpad.net/1.0/ubuntu/+archive/primary?ws.op=getPublishedSources&source_name=${pkg}&exact_match=true&status=Published&distro_series=https%3A%2F%2Fapi.launchpad.net%2F1.0%2Fubuntu%2F${series}"
  local version="$(curl -sfL "$api" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d['entries'][0]['source_package_version'] if d['entries'] else '')
except Exception:
    print('')
" 2>/dev/null)"
  [[ -z "$version" ]] && return 1

  local letter="${pkg[1]}"
  [[ "$pkg" == lib* ]] && letter="lib${pkg[4]}"

  local temp_dsc="$(mktemp /tmp/ub.XXXXXX)"
  local base=""
  for area in main universe multiverse restricted; do
    local candidate="http://archive.ubuntu.com/ubuntu/pool/${area}/${letter}/${pkg}"
    if curl -sfL "${candidate}/${pkg}_${version}.dsc" -o "$temp_dsc" 2>/dev/null; then
      base="$candidate"
      break
    fi
  done
  [[ -z "$base" ]] && { rm -f "$temp_dsc"; return 1; }

  local src_tar="$(grep -oE '[^ ]+\.orig\.tar\.(gz|xz|bz2|lzma|Z)$' "$temp_dsc" | head -n1)"
  [[ -z "$src_tar" ]] && src_tar="$(grep -oE "${pkg}_${version}\.tar\.(gz|xz|bz2|lzma)$" "$temp_dsc" | head -n1)"
  rm -f "$temp_dsc"
  [[ -z "$src_tar" ]] && return 1

  local downloaded_folder="${pkg}-${version}"
  read_dest file "$downloaded_folder" || return 0

  local temp_archive="$(mktemp /tmp/ub.XXXXXX)"
  success_or_log curl -sfL "${base}/${src_tar}" -o "$temp_archive" || { local code=$?; rm -f "$temp_archive"; return $code; }

  mkdir -p "$dest"
  success_or_log tar -xf "$temp_archive" -C "$dest" --strip-components=1 || { local code=$?; rm -f "$temp_archive"; return $code; }
  rm -f "$temp_archive"
  echo "$dest"
}


# Downloads the PKGBUILD (full AUR source snapshot) of an AUR package.
# Matched only for https://aur.archlinux.org/packages/<name> via DEFAULT.ini.
http.aur() {
  local url="$1"
  # NB: avoid the variable name `path` (zsh ties it to PATH)
  local sub="${url#*aur.archlinux.org/}"
  sub="${sub%%\?*}"
  sub="${sub%%\#*}"

  # Glob guarantees the packages/ prefix; bare /<name> never reaches this handler.
  local pkg="${sub#packages/}"
  pkg="${pkg%%/*}"
  pkg="${pkg%.git}"
  [[ -z "$pkg" ]] && return 1

  local json="$(curl -sfL "https://aur.archlinux.org/rpc/v5/info?arg[]=${pkg}")"
  [[ -z "$json" ]] && return 1
  local snap="$(printf '%s' "$json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d['results'][0]['URLPath'] if d['results'] else '')
except Exception:
    print('')
" 2>/dev/null)"
  [[ -z "$snap" ]] && return 1

  read_dest file "$pkg" || return 0

  local temp_tgz="$(mktemp /tmp/aur.XXXXXX.tar.gz)"
  success_or_log curl -sfL "https://aur.archlinux.org${snap}" -o "$temp_tgz" || { local code=$?; rm -f "$temp_tgz"; return $code; }

  mkdir -p "$dest"
  success_or_log tar -xzf "$temp_tgz" -C "$dest" --strip-components=1 || { local code=$?; rm -f "$temp_tgz"; return $code; }
  rm -f "$temp_tgz"
  echo "$dest"
}


####### SSH #######
# Args: userhost, subpath

ssh.clone() {
  read_dest ssh $2 || return 0 # read_dest provides a valid destination path to the dest variable given the path-like component corresponding to the protocol. For ssh handlers its $2 (the subpath), but $1 for other protocol handlers.

  success_or_log git clone --single-branch --filter=blob:none $ARGS $1:$2 $dest || return
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