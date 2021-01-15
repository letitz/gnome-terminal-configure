#!/bin/bash
# vim: tw=80 ts=2 sw=2:

set -eu

# CONSTANTS
# =========

PROGRAM_NAME="$0"

# DConf directory in which gnome-terminal profile configuration is stored.
ROOT_DCONF_DIR='/org/gnome/terminal/legacy/profiles:/'

# The names of ANSI color properties in config files.
# Order matters. These correspond to the ANSI color codes.
ANSI_COLOR_PROPERTIES=(
  "ansi-colors-black"
  "ansi-colors-red"
  "ansi-colors-green"
  "ansi-colors-yellow"
  "ansi-colors-blue"
  "ansi-colors-purple"
  "ansi-colors-cyan"
  "ansi-colors-white"
  "ansi-colors-bright-black"
  "ansi-colors-bright-red"
  "ansi-colors-bright-green"
  "ansi-colors-bright-yellow"
  "ansi-colors-bright-blue"
  "ansi-colors-bright-purple"
  "ansi-colors-bright-cyan"
  "ansi-colors-bright-white"
)

# LOGGING
# =======

# log ARGS...
# echo for stderr
function log() {
  echo 1>&2 "$@"
}

# die ARGS...
# log then exit with an error code
function die() {
  log "$@"
  exit 1
}


# CONFIG
# ======
#
# Configuration files have a very basic grammar:
#
#   PROPERTY_NAME = VALUE
#
# The functions below allow reading config file contents.

# config_get_property file property
# Echoes the given property from the given config file.
function config_get_property() {
  file="$1"
  property="$2"

  sed -n "s:^${property} *= *\(\.*\):\1:p" < "${file}"
}

# config_get_property_or_die file property
# config_get_property, except dies if the property is not found.
function config_get_property_or_die() {
  file="$1"
  property="$2"

  result=$(config_get_property "${file}" "${property}")
  if [ -z "$result" ]; then
    die "Error: cannot find property '${property}' in file '${file}'."
  fi

  echo "${result}"
}

# config_get_font file
function config_get_font() {
  file="$1"
  config_get_property "${file}" "font"
}

# config_get_foreground_color file
function config_get_foreground_color() {
  file="$1"
  config_get_property "${file}" "foreground-color"
}

# config_get_background_color file
function config_get_background_color() {
  file="$1"
  config_get_property "${file}" "background-color"
}

# join_ansi_colors COLOR1 ... COLOR16
# Echoes "[${COLOR1}, ..., ${COLOR16}]".
function join_ansi_colors () {
  echo -n "[$1"
  for i in {2..16}; do
    echo -n ", ${!i}"  # Get the i-th argument to this function.
  done
  echo "]"
}

# config_get_ansi_colors file
function config_get_ansi_colors() {
  file="$1"

  ansi_colors=()
  for property in "${ANSI_COLOR_PROPERTIES[@]}"; do
    # TODO: This does not actually die, because exit is called in a subshell.
    color=$(config_get_property_or_die "${file}" "${property}")
    ansi_colors+=("${color}")
  done

  join_ansi_colors "${ansi_colors[@]}"
}


# PROFILE
# =======
#
# Gnome-terminal profile preferences are read and written through dconf.
#
# In the following functions, profiles are referenced by their dconf directory
# paths (ending in a '/' character).

# profile_path ID
function profile_path() {
  id="$1"
  echo "${ROOT_DCONF_DIR}:${id}/"
}

# profile_list
function profile_list() {
  dconf list "${ROOT_DCONF_DIR}" | sed -nE 's_^:(.*)/$_\1_p'
}

# profile_get_property profile property
# Echoes the given property from the given gnome-terminal profile.
function profile_get_property() {
  profile="$1"
  property="$2"

  dconf read "${profile}${property}"
}

# profile_set_property profile property value
# Sets the given profile's given property to the given value.
function profile_set_property() {
  profile="$1"
  property="$2"
  value="$3"

  dconf write "${profile}${property}" "${value}"
}


# profile_get_name profile
# Echoes the human-readable name for the given gnome-terminal profile.
function profile_get_name() {
  profile="$1"
  profile_get_property "${profile}" "visible-name"
}

# profile_set_name profile value
# Sets the human-readable name for the given gnome-terminal profile.
function profile_set_name() {
  profile="$1"
  value="$2"
  profile_set_property "${profile}" "visible-name" "${value}"
}

# profile_get_font profile
# Echoes the font for the given gnome-terminal profile.
function profile_get_font() {
  profile="$1"
  profile_get_property "${profile}" "font"
}

# profile_set_font profile value
# Sets the font for the given gnome-terminal profile.
function profile_set_font() {
  profile="$1"
  value="$2"
  profile_set_property "${profile}" "font" "${value}"
}

# profile_get_foreground_color profile
# Echoes the foreground color for the given gnome-terminal profile.
function profile_get_foreground_color() {
  profile="$1"
  profile_get_property "${profile}" "foreground-color"
}

# profile_set_foreground_color profile value
# Sets the foreground color for the given gnome-terminal profile.
function profile_set_foreground_color() {
  profile="$1"
  value="$2"
  profile_set_property "${profile}" "foreground-color" "${value}"
}

# profile_get_background_color profile
# Echoes the background color for the given gnome-terminal profile.
function profile_get_background_color() {
  profile="$1"
  profile_get_property "${profile}" "background-color"
}

# profile_set_background_color profile value
# Sets the background color for the given gnome-terminal profile.
function profile_set_background_color() {
  profile="$1"
  value="$2"
  profile_set_property "${profile}" "background-color" "${value}"
}

# profile_get_ansi_colors profile
# Echoes the ANSI color palette for the given gnome-terminal profile.
function profile_get_ansi_colors() {
  profile="$1"
  profile_get_property "${profile}" "palette"
}

# profile_set_ansi_colors profile value
# Sets the ANSI color palette for the given gnome-terminal profile.
function profile_set_ansi_colors() {
  profile="$1"
  value="$2"
  profile_set_property "${profile}" "palette" "${value}"
}

# ansi_colors_build_regex INDEX
# Builds an extended regex to capture the color at INDEX as \2.
function ansi_colors_build_regex() {
  index="$1"

  if [ "${index}" -lt 0 ] || [ "${index}" -gt 15 ]; then
    die "Error: invalid ansi color index '${index}'."
  fi

  # Match the opening bracket, which must be the first character.
  echo -n "^\["

  # Skip the items before the target index, if any.
  if [ "${index}" -gt 0 ]; then
    # These all end in a trailing comma.
    echo -n "([^,]*,){$((${index}))}"
  else
    # Capture nothing so that the target capture group is \2.
    echo -n "()"
  fi

  # Capture the target group (and not the comma).
  echo -n "([^,]*)"

  # Skip the remaining items, if any.
  if [ "${index}" -lt 15 ]; then
    # These all start with a leading comma.
    echo -n "(,[^,]*){$((15 - ${index}))}"
  fi

  # Match the closing bracket, which must be the last character.
  echo '\]$'
}

# ansi_colors get "[ COLOR1, ..., COLOR16 ]" INDEX
ansi_colors_get() {
  colors_string="$1"
  index="$2"

  regex=$(ansi_colors_build_regex "${index}")
  echo "${colors_string}" | \
    sed -nE "s:${regex}:\\2:p" | \
    sed -e "s:^ *::" -e "s: *$::"  # Remove whitespace.
}

# dump_ansi_colors "[ COLOR1, ..., COLOR16 ]"
function dump_ansi_colors() {
  colors_string="$1"

  for i in {0..15}; do
    echo -n "${ANSI_COLOR_PROPERTIES[$i]} = "
    ansi_colors_get "${colors_string}" $i
  done
}

# profile_dump_config profile
function profile_dump_config() {
  profile="$1"

  font=$(profile_get_font "${profile}")
  foreground_color=$(profile_get_foreground_color "${profile}")
  background_color=$(profile_get_background_color "${profile}")
  ansi_colors=$(profile_get_ansi_colors "${profile}")

  echo "font = ${font}"
  echo "foreground-color = ${foreground_color}"
  echo "background-color = ${background_color}"
  dump_ansi_colors "${ansi_colors}"
}

# profile_apply_config profile config_file
# Applies the given configuration to the given gnome-terminal profile.
function profile_apply_config() {
  profile="$1"
  config_file="$2"

  font=$(config_get_font "${config_file}")
  foreground_color=$(config_get_foreground_color "${config_file}")
  background_color=$(config_get_background_color "${config_file}")
  ansi_colors=$(config_get_ansi_colors "${config_file}")

  profile_set_font "${profile}" "${font}"
  profile_set_foreground_color "${profile}" "${foreground_color}"
  profile_set_background_color "${profile}" "${background_color}"
  profile_set_ansi_colors "${profile}" "${ansi_colors}"
}

# INTERACTIVE USE
# ===============

# choose_number prompt_base min max
# Asks the user to choose a number between min and max, inclusive.
# prompt_base should not end in a newline.
function choose_number() {
  prompt_base="$1"
  min_number="$2"
  max_number="$3"

  while true; do
    read -p "${prompt_base} [${min_number} to ${max_number}]: " chosen_number
    if [ "${chosen_number}" -lt "${min_number}" ]; then
      continue
    fi
    if [ "${chosen_number}" -gt "${max_number}" ]; then
      continue
    fi

    echo "${chosen_number}"
    break
  done
}

# choose_profile
# Echoes the path to a valid gnome-terminal profile to modify.
function choose_profile() {
  # Build an array of profile subdirectories.
  profiles=()
  for profile_subdir in $(dconf list "${ROOT_DCONF_DIR}"); do
    profiles+=("${ROOT_DCONF_DIR}${profile_subdir}")
  done
  num_profiles="${#profiles[@]}"

  if [ "${num_profiles}" -eq 0 ]; then
    die "Error: found no gnome-terminal profiles to style."
  fi

  if [ "${num_profiles}" -eq 1 ]; then
    profile="${profiles[0]}"
    profile_name=$(profile_get_name "${profile}")
    log "Found single gnome-terminal profile named '${profile_name}', using it."
    echo "${profile}"
    return
  fi

  log "Available gnome-terminal profiles:"

  for i in $(seq 1 "${num_profiles}"); do
    profile="${profiles[$(($i - 1))]}"
    profile_name=$(profile_get_name "${profile}")
    log "  #$i: ${profile_name}"
  done

  choose_number "Choose a profile" 1 "${num_profiles}"
}

# usage ERROR
function usage() {
  ERROR="$1"

  log "Error: ${ERROR}"
  log
  log "USAGE: ${PROGRAM_NAME} SUBCOMMAND"
  log
  log "Where SUBCOMMAND can be one of:"
  log
  log "  list"
  log "    Lists the available gnome-terminal profiles."
  log
  log "  get [profile PROFILE_ID] PROPERTY"
  log "    Displays the given gnome-terminal profile property."
  log
  log "  set [profile PROFILE_ID] PROPERTY VALUE"
  log "    Sets the given gnome-terminal profile property to the given value."
  log
  log "  dump [profile PROFILE_ID]"
  log "    Dumps the given gnome-terminal as a configuration file to stdout."
  log
  log "  apply [profile PROFILE_ID] FILE"
  log "    Applies the gnome-terminal configuration file."
  die
}

# expect_arguments command expected actual
function expect_arguments() {
  command="$1"
  expected="$2"
  actual="$3"

  if [ "${actual}" -ne "${expected}" ]; then
    die "Error: ${command} expects ${expected} arguments, got ${actual}."
  fi
}

# subcommand_list
function subcommand_list() {
  expect_arguments "list" 0 $#

  profile_list
}

# unquote
# For each line in stdin, removes the start and end single quotes.
function unquote() {
  sed -nE "s:^'(([^'\]|\\.)*)'$:\1:p"
}

# quote string
# Quotes the given argument.
quote() {
  string="$1"

  # Surround with single quotes.
  # Escape all enclosed quotes with a backslash. We need two backslashes for a
  # reason that is not immediately clear to me. Something something the string
  # is unescaped afterwards?
  echo -n "'"
  echo -n "${string}" | sed "s:':\\\\':g"
  echo "'"
}

# subcommand_get profile property
function subcommand_get() {
  expect_arguments "get" 1 $(($# - 1))

  profile="$1"
  property="$2"

  case "${property}" in
    "font")
      profile_get_font "${profile}" | unquote
      ;;
    "foreground-color")
      profile_get_foreground_color "${profile}" | unquote
      ;;
    "background-color")
      profile_get_background_color "${profile}" | unquote
      ;;
    "palette")
      profile_get_ansi_colors "${profile}"
      ;;
    *)
      die "unknown profile property '${property}'"
      ;;
  esac
}

# subcommand_set profile property value
function subcommand_set() {
  expect_arguments "set" 2 $(($# - 1))

  profile="$1"
  property="$2"
  value="$3"

  case "${property}" in
    "font")
      quoted=$(quote "${value}")
      profile_set_font "${profile}" "${quoted}"
      ;;
    "foreground-color")
      quoted=$(quote "${value}")
      profile_set_foreground_color "${profile}" "${quoted}"
      ;;
    "background-color")
      quoted=$(quote "${value}")
      profile_set_background_color "${profile}" "${quoted}"
      ;;
    "palette")
      profile_get_ansi_colors "${profile}"
      ;;
    *)
      die "unknown profile property '${property}'"
      ;;
  esac
}

# subcommand_dump profile
function subcommand_dump() {
  expect_arguments "dump" 0 $(($# - 1))

  profile="$1"

  profile_dump_config "${profile}"
}

# subcommand_apply profile
function subcommand_apply() {
  expect_arguments "apply" 0 $(($# - 1))

  profile="$1"

  # Copy stdin to a temporary file.
  config_file=$(mktemp)
  tee > "${config_file}"

  # Apply the configuration file.
  profile_apply_config "${profile}" "${config_file}"
}

function main() {
  if [ "$#" -le 0 ]; then
    usage "Subcommand required."
  fi

  subcommand="$1"
  shift

  # Validate subcommand
  need_profile=1
  case "${subcommand}" in
    "list")
      need_profile=0
      ;;
    "get")
      ;;
    "set")
      ;;
    "dump")
      ;;
    "apply")
      ;;
    *)
      usage "Unrecognized command '${subcommand}'."
      ;;
  esac

  # Commands that do not need a profile can just execute now.
  if [ "${need_profile}" -eq 0 ]; then
    "subcommand_${subcommand}" "$@"
    return
  fi

  # Parse the optional `profile PROFILE_ID` clause if present.
  if [ "$#" -ge 1 ] && [ "$1" == "profile" ]; then
    if [ "$#" -eq 1 ]; then
      usage "expected profile ID after 'profile' keyword."
    fi

    profile=$(profile_path "$2")
    shift 2
  else
    profile=$(choose_profile)
  fi

  # Execute the subcommand.
  "subcommand_${subcommand}" "${profile}" "$@"
}

main "$@"
