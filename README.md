# Todofi.sh

Todo-txt + Rofi = Todofi.sh

Handle your [todo-txt](http://todotxt.org/) tasks directly from [Rofi](https://github.com/DaveDavenport/rofi)

![Todofi.sh screenshot](screenshot.png)

## Features

* Mark as done
* Create, Edit, Delete
* Edit priority, remove priority
* Apply persistent filters
* Filter from context / project
* Run command like archive, deduplicate or report
* Can apply filter from argument
* Context / Project / Tag / Due highlighting (via Pango markup)

## Dependencies

* rofi
* todo-txt

#### On Debian based system

```bash
sudo apt install rofi todo-txt
```

## Installation

Copy todofi.sh where you want.

## Use it

Just run `/your/path/todofi.sh`

With i3wm, you can bind todofi.sh like this `bindsym $mod+t exec /path/to/todofi.sh`

Try `todofi.sh --help` if you want to customize.

## Customization

If you want to override Todofi.sh configuration, do not edit directly the todofi.sh script, you can do that by:

* Add configuration in `${HOME}/.config/todofish.conf` (Todofi.sh tries to source this file when it starts)
* Open todofi.sh by specify a configuration file with the `-c` argument (exemple: `todofi.sh -c /path/to/todofish.conf`)

Because the configuration file is loaded last, you can overwrite any configuration variable.

So if you want to add arguments to Rofi, you can do so with the content of the following configuration file:

```bash
ROFI_BIN="$(command -v rofi) -theme /usr/share/rofi/themes/fancy.rasi"
```
