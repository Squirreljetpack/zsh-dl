# zsh-dl: Basic Downloader

`zsh-dl` is a tool for downloading and post-processing files.

The tool itself doesn't actually do any downloading or processing. Instead, it's a purely logical framework for defining whatever tree/case-type logic you may have for your input. But it makes defining handlers and invoking them simple and easy.

```zsh

dl "https://github.com/Squirreljetpack/zsh-dl/tree/main/config" # downloads the folder into your current directory

# with clipboard content: https://www.reddit.com/r/proceduralgeneration/comments/1g5xi6j/a_skull_made_in_a_pixel_shader_no_mesh_no/
dl # a_skull_made_in_a_pixel_shader_-_no_mesh_no_geometry_just_code.mkv

# Alternate config:
dl -ca "https://www.youtube.com/watch?v=l5ihnPWKJZU" # Downloads audio (using the alternate config) into your current directory.
dl -ca "https://www.reddit.com/r/interesting/comments/1l114tz/an_arctic_weather_station_on_abandoned_kolyuchin/" # Downloads images into your current directory.
```

[^1]: External dependencies are required.

https://github.com/user-attachments/assets/55a36923-0bad-48fe-bc76-a382834af399


## Key Features


### 🚀 Plug and Play

- Built-in handlers for:

  - GitHub/GitLab repositories (download folders/files/branches)

  - Project Gutenberg books (auto-convert to Markdown)

  - Media downloads (images/videos/audio)[^1]
  
  - Multithreaded, chunked and resumable downloads
  
- Post-processors for formatting and conversion:
  - Markdown conversion
  
  - Define your own universal formatter

- Reads from your clipboard for minimal fuss

- Uses [lt](https://github.com/Squirreljetpack/lt) if installed for hassle-free destination determination

### ⚙ Dead Simple Configuration

- Declare handlers and postprocessors for various input types:

- Define different configs for processing input of different types or in different modes

```ini
# config/default.ini
http.my_handler="example.com/*" # Handle urls beginning with example.com/ with an http.myhandler you define
http.default:markdown="*" # Download all other http/s urls with curl, and convert them to markdown

# Additionally:
# - using | as the first seperator allows matching multiple patterns
# - and multiple processors can be chained, like so:
# http.default|markdown:htmlify

ZSHDL_THREADS=5 # 5 download threads
```

```shell

# Run with
dl -x "https://jless.io/user-guide"
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
> dl -cf * # format all your files with default settings
```

[^2]: ok yes it does feel kinda useless considering that its not much harder to just call curl or rsync. But github download is pretty nice, and even if its an overengineered alias, its still pretty handy to use. Feel free to give it a try! Also, there is a purpose in all of it, even if it'll probably take a rewrite in Rust :p.

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

### 📋 Task management

- Queue your input, cancel anytime, and resume where you left off

- More on the way


# Installation

```bash
git clone git@github.com:Squirreljetpack/zsh-dl.git
cd zsh-dl
./install.zsh
```

The installer will prompt you for what to name the executable as. The default is dl but you may want to choose a longer name and create a shell alias instead.

### Dependencies

zsh-dl relies on the following external command-line tools. Certain functionality will be disabled without them:

- [lt](https://github.com/Squirreljetpack/lt): For determining download destination.
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
Usage: dl [-hlesvq] [-c name] [-r count] [-x input] […log_ids/…method_args]

Extensible cli download tool.

Options:
  -c <name>         : Use name.ini in /home/archr/.config/zsh-dl as the config.
  -e                : Edit configuration files.
  -h                : Display this help message and exit.
  -l […log_ids]     : Show the log for the given log_ids.
                        'n:' to display the last n logs
                        '.s' to filter by status
  --from [log_id=0] : Retry failed downloads.
  -s                : Skip inputs which succeded in the past.
  -v                : Set verbosity 2.
  --queue [file]    : Append input to and read from queue file.
                        If $ZSHDL_QUEUE_FILE is set, this option is automatically true.
  -q                : Use the default queue file
  --verbose [level] : Set verbosity level.
  --clear [glob]    : Clear logs.
  …method_args      : Passed to the ARGS array of methods.
                        ':' applies the arguments to the next stage's method.

Environment variables and configuration:
  See dl -v -h

Examples:
  dl
    Parses clipboard for urls to download
  dl "https://gutenberg.org/ebooks/76257"
    Download book #76257 as a markdown file
  dl "https://github.com/sumoduduk/terminusdm/tree/main/src"
    Download the src/ folder of the sumoduduk/terminusdm in the main branch to the current directory
  dl "user@host:path/to/your/file.tx"
    Downloads over SSH
  dl -ci "google.com"
    Gets info about a URL/file
  dl -cf "path/to/your/script.zsh" "random_weather.py"
    Format local files using the fmt.ini config
  dl -ca --queue urls.txt
    Download audio from a list of youtube urls (with alternate.ini)
  dl -q < urls.txt
    Add URLs to and start the default queue.

Status codes:

   …: Misc/Processing
  -2: Unhandled/Skipped
  -1: Partial Success
   0: Success
  >0: Handling error
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
    - `IMAGESDLcmd`


</br>

- Sourcing:
  - Different configs are defined as seperate `name`.ini files
  - For convenience, configs can be invoked with `-c <nickname>` where `<nickname>` is any string such that there is only one config that has it as an initial substring.
  - Before running, all corresponding `<name>_*.zsh` files along with the preinstalled `handlers.zsh` and `postprocessors.zsh` in the config directory are sourced.


# Future directions [^4] 

- Use a more powerful expression language than glob
- Advanced mime detection
- Lessfilter implementation
- Even more generalized composition
- Draw a diagram
- Daemonize
- Support passing flags to handlers
- Maintain an input history to resume from in case of early exit
- Buffer tty read + write requests with redraw
- URI handling maybe
- Debug empty lines on stdout

[^4]: which probably won't happen anytime soon
