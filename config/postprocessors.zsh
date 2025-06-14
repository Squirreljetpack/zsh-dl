# Define postprocessor functions in this file. All postprocessors must have the format pp_name.
# Postprocessors are automatically attached to handlers of the same name.
# A postprocessor can be attached to a multiple handlers by a decoration after a glob rule, see default.ini. 

# Args: source (the output of the submitting handler, i.e. downloaded file path)
# Output: The postprocessed filepath on success

pp_markdown() {
  read_dest file $1:r.md -a || return 0
  print -u2 
  success_or_log ${=HTML2MARKDOWNcmd} --output $dest < $1 || return
  echo $dest && rm $1
}