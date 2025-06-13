# zsh-dl: Basic Downloader

`zsh-dl` is a tool for downloading and post-processing files.

The tool itself doesn't actually do any downloading or processing. Instead, it's a purely logical framework for defining whatever tree/case-type logic you may have for your input. But it makes defining handlers and invoking them simple and easy.

```zsh

dl "https://github.com/Squirreljetpack/zsh-dl/tree/main/config" # downloads the folder into your current directory
dl # Downloads the urls on your clipboard and converts them to markdown
dl -cd "https://www.reddit.com/r/interesting/comments/1l114tz/an_arctic_weather_station_on_abandoned_kolyuchin/" # Downloads the images (or video) into your current directory.
```

[^1]: External dependencies are required.

## Key Features

### 🚀 Plug and Play

- Built-in handlers for:

  - GitHub/GitLab repositories (download folders/files/branches)

  - Project Gutenberg books (auto-convert to Markdown)

  - Media downloads (images/videos)[^1]
  
  - Multithreaded, chunked and resumable downloads
  
- Post-processors for formatting and conversion:
  - Markdown conversion
  
  - Define your own universal formatter

- Reads from your clipboard for minimal fuss

- Uses [pere](https://github.com/Squirreljetpack/pere) if installed for hassle-free destination determination

### ⚙ Dead Simple Configuration

- Declare handlers and postprocessors for various input types:

- Define different configs for processing input of different types or in different modes


```ini
# config/default.ini
http.my_handler="example.com/*" # Handle urls beginning with example.com/ with an http.myhandler you define
http.default:markdown="*" # Download all other http/s urls with curl, and convert them to markdown

ZSHDL_THREADS=5 # 5 download threads
```

```shell

# Run with
dl "https://jless.io/user-guide"
# or
dl < urls.txt
# or just
dl # read from your clipboard

```


### 🧩 Elegant Extension System

The base functionality is pretty sparse. But for my own use case, there's only a few types of behavior I want depending what's on my clipboard, which zsh-dl makes easy to define and invoke[^2]:

- Define handlers directly in Zsh: no fussing about documentation and DSL's.

- Reuse components across different protocols

```shell
# The diagram goes
# Internal: [INPUT] -> [PROTOCOL HANDLER] -> [PROTOCOL-SPECIFIC HANDLER] ->
# Modular : [HANDLER] (❤️ You are here) -> [POSTPROCESSOR] -> ... ->
# -> [OUTPUT] (+ logging)


# config/handlers.zsh
file.fmt_ruff() {
  file=$1
  [[ -e ~/ruff_$FORMAT.toml ]] &&
    opts+=(--config ~/ruff_$FORMAT.toml) ||
    opts=()
  ruff format $opts $1
}
```
```ini
# config/fmt.ini
file.fmt_ruff="*.py" # handle python files with fmt_ruff
file.fmt_biome="*.(js|ts|tsx|jsx|astro|html|css)"
```
```shell
# format all your files with strict settings

> FORMAT=strict dl --config fmt *
# or just
> dl -cf *
# format all your files with default settings
```

[^2]: ok yes it does feel kinda useless considering that its not much harder to just call curl or rsync. But the github download is useful imo, reduced cognitive load is always nice, and maybe the other parts might be of use to someone else. Also, have I mentioned its dead simple?

See [Configuration](#handlers-and-preprocessors) for the actual inputs provided to and outputs expected of these handlers.

### 📊 Robust Logging & Statistics

- SQLite database tracks history per config

- Skip past executions

- Retry failed downloads

```shell
> dl -s
┌────┬────────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┬──────────────────────────────┬──────┐
│ ID │      Time      │                  Target                  │                 Message                  │         Destination          │ St.  │
├────┼────────────────┼──────────────────────────────────────────┼──────────────────────────────────────────┼──────────────────────────────┼──────┤
│ 3  │ 06-13 14:46:32 │ Do you know the Muffin man The Muffin m… │ [Unhandled]                              │                              │  -2  │
│ 2  │ 06-13 14:37:06 │ google.com/search?q=nb%20github%20bash%… │                                          │   ~/SCRIPTS/zsh-dl/search.md │  3   │
│ 1  │ 06-13 14:37:06 │ google.com/search?q=nb%20github%20bash%… │ [PP: markdown] invoked for /home/usern/… │ ~/SCRIPTS/zsh-dl/search.html │  0   │
└────┴────────────────┴──────────────────────────────────────────┴──────────────────────────────────────────┴──────────────────────────────┴──────┘

```

# Installation

```bash
git clone git@github.com:Squirreljetpack/zsh-dl.git
cd zsh-dl
./install.zsh
```

The installer will prompt you for what to name the executable as. The default is dl but you may want to choose a more explicit name and create a shell alias instead.

### Dependencies

zsh-dl relies on the following external command-line tools. Certain functionality will be disabled without them:

- [pere](https://github.com/Squirreljetpack/pere): For determining download destination.
- [sqlite3](https://www.sqlite.org/download.html): For logging.
- clipboard commands (xclip/pbcopy[^3]): For reading from clipboard.
[^3]: preinstalled on Mac

You surely already have these:
- curl: For HTTP/HTTPS downloads.
- rsync: For SSH/SFTP transfers.
- git: For cloning repositories.
- tar: For extracting archives.
- file: For determining file and MIME types.

And the predefined handlers/postprocessors are just wrappers around these:
   - [yt-dlp](https://github.com/yt-dlp/yt-dlp)
   - [gallery-dl](https://github.com/mikf/gallery-dl)
   - [html2markdown](https://github.com/JohannesKaufmann/html-to-markdown)
   - [Ruff](https://github.com/astral-sh/ruff) / [Biome](https://github.com/biomejs/biome) / [shellfmt](https://github.com/mvdan/sh)
   

All these can be easily reconfigured through setting variables or writing a handler.

# Usage

```
Usage: dl [-hlesv] [-c name] [--from log_id] […inputs/…log_ids]

Basic cli extensible download tool.

Options:
  -c <name>         : Sets name.ini in /home/archr/.config/zsh-dl as the config.
  -e                : Edit configuration files.
  -h                : Display this help message and exit.
  -l […log_ids]     : Show the log for the current config.
  --from [log_id=1] : Retry failed downloads from log_id.
  -s                : Skip inputs which succeded in the past. ( ZSHDL_SKIP=true|false )
  -v [level=2]      : Set the verbosity level. ( VERBOSE=[0-9] )

Environment variables and configuration:
  See dl -v -h

Examples:
  dl
    Parses clipboard for urls to download
  dl "https://gutenberg.org/ebooks/76257"
    Download book #76257 as a markdown file
  dl "https://github.com/sumoduduk/terminusdm/tree/main/src"
    Download the src/ folder of the sumoduduk/terminusdm in the main branch to the current directory
  dl "user@host:path/to/your/file.tx
    Downloads over SSH
  dl -ci "google.com"
    Gets info about a URL/file
  dl -cf "path/to/your/script.zsh" "random_weather.py"
    Format local files using the fmt.ini config
  dl -cm < urls.txt
    Process a list of URLs in a file (media.ini):

Status codes:
  -2: Unprocessed/Unhandled
  -1: Handling
   0: HandlerSuccess
   1: HandlerError
   2: PPError
   3: PPSuccess
   4: InternalErro
```

# Configuration

Configuration is read from `ZSHDL_CONFIG_DIR`, defaulting to `~/.config/zsh-dl`.

### Handlers and Preprocessors
See `dl -v --help`

### Configs
- Glob patterns:
  - Define a handler and optional postprocessor for an input pattern like so:
    - `handler(:processor)="*" # comments are allowed`
  - Handlers are matched sequentially in the order they are defined
  - Use `|` instead of `:` to continue onto other matching handlers

</br>

- Environment variables:
  - General: See `dl -v --help`
  - Specific to the example methods (these are autodetected if not declared):
    - `CLIPcmd`
    - `PASTEcmd`
    - `FORMATPYTHONcmd`
    - `HTML2MARKDOWNcmd`
    - `YTDLPcmd`
    - `GALLERYDLcmd`


</br>

- Sourcing:
  - Different configs are defined as seperate `name`.ini files
  - For convenience, configs can be invoked with `-c <nickname>` where `<nickname>` is any string such that there is only one config that has it as an initial substring.
  - Before running, all corresponding `<name>_*.zsh` files along with the preinstalled `handlers.zsh` and `postprocessors.zsh` in the config directory are sourced.


# Future directions [^4] 

- Create a screenshare
- Use a more powerful expression language than glob
- Advanced mime detection
- Lessfilter implementation
- Generalized composition
- Draw a diagram
- Daemonize


[^4]: which probably won't happen anytime soon
