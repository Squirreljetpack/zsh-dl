#!/bin/zsh

set +x

# download an image or video
dl "https://www.reddit.com/r/interesting/comments/1l5atla/male_bee_dies_after_ejaculation_while_mating_with/"

# skip downloaded
dl -s "https://www.reddit.com/r/interesting/comments/1l5atla/male_bee_dies_after_ejaculation_while_mating_with/" 

# download a github folder
dl "https://github.com/Squirreljetpack/zsh-dl/tree/main/config"           


# download over ssh (failed connection)
dl "archr@archr:biome.json"       

# get info
dl -ci "https://google.com"

# unhandled
dl -ci "Do you know the Muffin man The Muffin man, the Muffin man"

# format a file
dl -cf "broken.zsh" 

# Multithreaded + Prompting
dl "https://gutenberg.org/ebooks/76257" "https://gutenberg.org/ebooks/76257"

# view logs
dl -l

# per-config logs
dl -cf -l

# log details
dl -cf -l 1