# zsh-dl: Dead Simple Downloader

`zsh-dl` is a dead simple tool for downloading and post-processing files.

The tool itself doesn't actually do any downloading or processing[^1]. Instead, it's a purely logical framework for defining whatever tree/case-type logic you may have for your input.
But it streamlines the process of defining handlers and invoking them.


```zsh

dl "https://github.com/Squirreljetpack/zsh-dl/tree/main/config" # downloads the config folder of the branch into your current directory
dl # Downloads the urls on your clipboard and converts them markdown
dl -cd "https://www.reddit.com/r/interesting/comments/1l114tz/an_arctic_weather_station_on_abandoned_kolyuchin/" # Downloads images or video into your current directory.
```

[^1]: So external dependencies such as html-to-markdown and yt-dlp are required for the following examples.

## Key Features

### 🚀 Plug and Play

- Built-in handlers for:

  - GitHub/GitLab repositories (download folders/files/branches)

  - Project Gutenberg books (auto-convert to Markdown)

  - Media downloads (images/videos)
  
  - Multithreaded, chunked and resumable downloads
  
- Post-processors for formatting and conversion:
  - Markdown conversion

- Reads from your clipboard for minimal fuss
- Uses [peripet](https://github.com/Squirreljetpack/peripet) for hassle-free destination determination

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

The base functionality is pretty sparse. But for my own use case, there's only a few types of behavior I want depending what's on my clipboard, which zsh-dl makes easy to define and invoke[^4]:

- Define handlers directly in Zsh: no fussing about documentation and DSL's.
- Reuse components across different protocols

```shell
# config/handlers.zsh
file.fmt_ruff() {
  file=$1
  [[ -e ~/ruff_$FORMAT_VARIANT.toml ]] && opts+=(--config ~/ruff_$FORMAT_VARIANT.toml) || opts=()
  ruff format $opts $1
}
```

```ini
# config/fmt.ini
file.fmt_ruff="*.py" # handle python files with fmt_ruff
file.fmt_biome="*.(js|ts|tsx|jsx|astro|html|css)"
```

```shell
> dl --config fmt *
# format all your files with default settings
> FORMAT=strict dl -cf *
# format all your files with strict settings
```

[^4]: ok yes it does feel kinda useless considering that its not much harder to just call curl or rsync. But the github download is useful imo, reduced cognitive load is always nice, and maybe the other parts might be of use to someone else. Also, have I mentioned its dead simple?

[See](#handlers-and-preprocessors) for the actual inputs provided and outputs expected for these handlers.

### 📊 Robust Logging & Statistics

- SQLite database tracks history per config
- Skip past executions*
- Retry failed downloads*

```
+------+------------------------------------------+------------------------------------------+-----------------------------------+
| St.  |                      Target              |                         Message          |              Destination          |
+------+------------------------------------------+------------------------------------------+-----------------------------------+
|  0   | github.com/nitefood/asn/blob/master/asn  |                                          |     …/network_net_select/asn.html |
|  3   | man7.org/linux/man-pages/man2/read.2.ht… |                                          |        ~/SCRIPTS/zsh-dl/read.2.md |
|  0   | [PP: markdown] invoked for /home/archr/… | [PP: markdown] invoked for /home/archr/… |                                   |
|  1   | invalid                                  | curl: (6) Could not resolve host: www.e… |        …/errors/invalid_host.html |
+------+------------------------------------------+------------------------------------------+-----------------------------------+

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

- [peripet](https://github.com/Squirreljetpack/peripet): For determining download destination.
- [sqlite3](https://www.sqlite.org/download.html): For logging.
- clipboard commands (xclip/pbcopy[^2]): For reading from clipboard.

[^2]: preinstalled in Mac

You surely already have these:
- curl: For HTTP/HTTPS downloads.
- rsync: For SSH/SFTP transfers.
- git: For cloning repositories.
- tar: For extracting archives.
- file: For determining file and MIME types.

The predefined handlers/postprocessors are just wrappers around these:
   - [yt-dlp](https://github.com/yt-dlp/yt-dlp)
   - [gallery-dl](https://github.com/mikf/gallery-dl)
   - [html2markdown](https://github.com/JohannesKaufmann/html-to-markdown)
   - [Ruff](https://github.com/astral-sh/ruff) / [Biome](https://github.com/biomejs/biome) / [shellfmt](https://github.com/mvdan/sh)
   

All these can be easily reconfigured through setting variables or writing a handler.

# Usage

```
dl [OPTIONS] [URL_OR_PATH...]

If no URL_OR_PATH is provided, zsh-dl will attempt to read from the clipboard.

Examples

(See example.zsh for more)

 1 Download a book from Project Gutenberg as Markdown:

   dl "https://gutenberg.org/ebooks/76257"

 2 Download a specific folder from a GitHub repository:

   dl # From your clipboard containing https://github.com/Squirreljetpack/zsh-dl/tree/main/zsh-dl

 3 Download a file over SSH:

   dl "user@host:path/to/your/file.txt"

 4 Get info about a URL/file:

   dl -ci "google.com"

 5 Format a local Zsh file using a config (fmt.ini):

   dl -cf "path/to/your/script.zsh"

 6 Process a list of URLs in a file (media.ini):

   dl -cm < urls.txt
```

# Configuration

Configuration is read from `ZSHDL_CONFIG_DIR`, defaulting to `~/.config/zsh-dl`.

### Handlers and Preprocessors
See `VERBOSE=3 dl --help`

### Configs
- Glob patterns:
  - Define a handler and optional postprocessor for an input pattern with `handler(:processor)="*" # comments are allowed`
  - Handlers are matched sequentially in the order they are defined
  - Use `|` instead of `:` to continue onto other matching handlers
</br>
- Environment variables:
  - General:
    - `ZSHDL_CONNECT_TIMEOUT ZSHDL_THREADS ZSHDL_PP_THREADS VERBOSE ZSHDL_OUTPUT_DIR ZSHDL_LOG_DISPLAY_LIMIT ZSHDL_STATE_DIR ZSHDL_CONFIG_DIR`
  - Advanced:
    - `ZSHDL_FORCE_PROTO`
  - Specific to the example methods (these are autodetected if not declared):
    - `CLIPcmd PASTEcmd FORMATPYTHONcmd HTML2MARKDOWNcmd YTDLPcmd GALLERYDLcmd`

</br>

- Sourcing:
  - Different configs are defined as seperate `name`.ini files
  - For convenience, configs can be invoked with `-c <nickname>` where `<nickname>` is any string such that there is only one config that has it as an initial substring.
  - Before running, all corresponding `<name>_*.zsh` files along with the preinstalled `handlers.zsh` and `postprocessors.zsh` in the config directory are sourced.


# Future directions

### Todo

- Need to finish writing the usage
- the logging schema needs a rework to better describe and track execution events and states, as well as to better handle workflows which do not involve files.
- Create a screenshare

\* Implement retries
### Improvements [^3] 
- Improve logging schema
- Use a more powerful expression language than glob
- Lessfilter implementation
- Generalized composition


[^3]: which probably won't happen anytime soon