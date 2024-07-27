#!/bin/sh
nl="
"
space=" "
[ $ZSH_VERSION ] && {
  setopt sh_word_split
  setopt null_glob
}
shcat() {
  IFS=""
  while read -r line || [ "$line" ]; do
    printf '%s\n' "$line"
  done
# might be better as for IFS loop
# but some shells have issues with IFS
}
find () {
  for file in "${1%/}/"*; do
    # using dotfiles likely causes issues
    file="${file#./}"; file="${file%/}"; file="${file#/}"; file="${file#${1#./}}"
    # bunch of fixes for formatting
    case "${file#/}" in
      '.'|'..'|'.*'|'*') continue ;;
    esac
    # case check for .. & . & * & .*
    [ -d "${1%/}/${file#/}" ] && {
      dirname="${1%/}/${file#/}"
      [ "$2" ] && dirname="${2:+${2}/}${dirname#./}"
      # all these checks are for freebsd sh
      # a case check is likely better here tbh
      printf '%s\n' "${dirname}"
      [ "$find_orig_path" ] || find_orig_path="$PWD"
      cd "${dirname#${2}/}"
      find "./" "${dirname}"
      cd "$find_orig_path"
    } || {
      filename="${1%/}/${file#/}" 
      [ "$2" ] && filename="${2:+${2}/}${filename#./}"
      printf '%s\n' "$filename"
    }
  done
}
comp() {
  [ -e "$1/" ] || return 1
  ### find()
  unset IFS
  [ "$orig_path" ] || orig_path="$PWD";
  [ ! "$1" ] && return 1;
  [ -e "$1" ] || return 1
  for file in $(find "$1"); do
    #printf '%s\n' "'$file' | $PWD"
    [ -d "$file" ] && continue
    case "$(read line < $file; printf '%s\n' "$line")" in
      '#!/bin/sh'*|'#!/usr/bin/env bash'*) :;;
      *) continue;;
    esac
    basename="${file##*/}"
    eval [ \$"${basename#*=}" = "disabled" ] 2>/dev/null && continue
    #printf '%s\n' "$file"
    case "$basename" in
      *"bindgen.sh"*|*"standalone.sh"*) continue;;
    esac
    printf '%s\n' "${basename}() {"
    while IFS= read -r line || [ "$line" ]; do
      case "$line" in
        '#!/bin/sh'*|'#!/usr/bin/env bash'*) :;;
        *"exit"*)
          line="${line%%exit*}return${line##*exit}"
          printf '%s\n' "$line"
          ;;
        *) printf '%s\n' "$line";;
      esac
    done << EOF
$(shcat < "$file")
EOF
    printf '%s\n' "}"
    cd "$orig_path"
  done
}
while [ "$1" ]; do
  case "$1" in
    "conf="*) conf="${1#*=}";;
    "disable="*) 
    eval "${1#*=}=disabled"
    eval [ \$"${1#*=}" = "disabled" ] || {
      printf '%s\n' "!! ERROR: eval failed to disable function ${1#*=}" >&2
      printf '%s\n' "!! ERROR: This is likely an issue with the shell at /bin/sh" >&2
      exit 1
    }
    ;;
    # the above evals were tested with oksh, zsh, freebsd sh, and bash
    # and confirmed working
    # this is again a fail safe for future proofing
    ##
    # using eval is simpler later
    # as if a list is used, it has to be parsed
    # where with eval we can just do the above again
    # this spawns a subshell; but prevents additional loops for list parsing
  esac
  shift 1
done
# attempt to handle arguments
# getopts is NOT posix thus a while [ "$1" ] and shift loop is used
# this moves through each argument and handles it
# all arguments are lost after handling
##
[ "$conf" -a -e "$conf" ] && {
  . "$conf"
  #type source && source "$conf"
  # use source if the shell supports it
  # if I'm not wrong source is required for some extensions in some shells 
}
# load config

[ "$src" ] || src="./src"
[ -e "$src" ] || {
  printf '%s\n' "!! ERROR: there is nothing to compile..? no ./src or folder at ${src:-\$src}" >&2
  exit 1
}
[ "$lib" ] || lib="./lib"
# libraries aren't needed
# compile data in "$1/" into functions and output
comp "$lib"
comp "$src"
