# Define postprocessor functions in this file. All postprocessors must have the format pp_name.
# Postprocessors are automatically attached to handlers of the same name.
# A postprocessor can be attached to a different handler by a decoration after a glob rule, see default.ini. 

# Args: source (the output of the submitting handler, i.e. downloaded file path)
# Output: The transformed filepath on success

pp_markdown() {
  src=$1
  dest=$(get_dest file $src:r.md -a)
  success_or_log html2markdown --output $dest < $src &&
  echo $dest &&
  rm $src
}