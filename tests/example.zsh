#!/bin/zsh

set +x

# download an image or video
dl -x "https://www.reddit.com/r/proceduralgeneration/comments/1g5xi6j/a_skull_made_in_a_pixel_shader_no_mesh_no/"

# skip downloaded
dl -sx "https://www.reddit.com/r/proceduralgeneration/comments/1g5xi6j/a_skull_made_in_a_pixel_shader_no_mesh_no/"

# download a github folder
dl -x "https://github.com/Squirreljetpack/zsh-dl/tree/main/config"

# download over ssh (failed connection)
dl -x "archr@archr:biome.json"

# get info
dl -ci -x "https://google.com"

# unhandled
dl -ci -x "Do you know the Muffin man The Muffin man, the Muffin man"

# format a file
dl -cf -x "broken.zsh"

# Multithreaded + Prompting
dl -x "https://gutenberg.org/ebooks/76257" -x "https://gutenberg.org/ebooks/76257"

# view logs
dl -l

# per-config logs
dl -cf -l

# log details
dl -cf -l 1
