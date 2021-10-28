# gnome-terminal-configure

A small command-line utility to configure gnome-terminal.

Allows setting the main style properties of the terminal: font and colors. It
could be extended to cover a few other properties with a little more work, but
it works well enough for my purposes as is.

Settings can be backed up to a simple file format, then restored. This allows
defining and sharing simple color schemes for the terminal beyond the list of
default schemes supported natively.

## Usage

```
USAGE: ./gnome-terminal-configure.sh SUBCOMMAND

Where SUBCOMMAND can be one of:

  list
    Lists the available gnome-terminal profiles.

  get [profile PROFILE_ID] PROPERTY
    Displays the given gnome-terminal profile property.

  set [profile PROFILE_ID] PROPERTY VALUE
    Sets the given gnome-terminal profile property to the given value.

  dump [profile PROFILE_ID]
    Dumps the given gnome-terminal as a configuration file to stdout.

  apply [profile PROFILE_ID]
    Applies the gnome-terminal configuration passed to stdin.
```
