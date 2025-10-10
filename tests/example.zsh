#!/bin/zsh

set +x

# download an image or video
dl - "https://www.reddit.com/r/proceduralgeneration/comments/1g5xi6j/a_skull_made_in_a_pixel_shader_no_mesh_no/"

# skip downloaded
dl -s - "https://www.reddit.com/r/proceduralgeneration/comments/1g5xi6j/a_skull_made_in_a_pixel_shader_no_mesh_no/"

# download a github folder
dl - "https://github.com/Squirreljetpack/zsh-dl/tree/main/config"

# download over ssh (failed connection)
dl - "archr@archr:biome.json"

# get info
dl i - "https://google.com"

# unhandled
dl i - "Do you know the Muffin man The Muffin man, the Muffin man"

# format a file
dl f - "fmt.zsh"

# track failed files
dl f - "broken.zsh"

# Multithreaded + Prompting
dl - "https://gutenberg.org/ebooks/76257" - "https://gutenberg.org/ebooks/76257"

# view logs
dl -l

# per-config logs
dl f -l

# log details
dl f -l 1
