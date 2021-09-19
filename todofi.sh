#! /usr/bin/env bash

VERSION="1.0.0"

TODOTXT_CFG_FILE="${HOME}/.config/todo/config"

CONFIG_FILE="${HOME}/.config/todofish.conf"
FILTER_FILE="`dirname ${CONFIG_FILE}`/todofish_filter.sh"

FILTER=""
KIND=""

# if LINES_MODE == auto, window height is set from the lines count
# and by following the constraints LINES_MIN and LINES_MAX
LINES_MODE="auto"
LINES_MIN=1
LINES_MAX=15

COLOR_TITLE="#00CC00"
COLOR_SHORTCUT="#0000CC"
COLOR_INFO="#FF0000"
COLOR_EXAMPLE="#0000CC"
COLOR_ITEM="#0000FF"

# Don't forget to quote regex char
MARKUP_PRIORITY='<b>\1<\/b> \2'
MARKUP_PROJECT='<span fgcolor="darkblue"><b>\1<\/b><\/span>'
MARKUP_CONTEXT='<span fgcolor="darkgreen"><b>\1<\/b><\/span>'
MARKUP_TAG='<span fgcolor="gray"><b>\1<\/b><\/span>'
MARKUP_DUE='<span fgcolor="red"><b>\1<\/b><\/span>'

SHORTCUT_NEW="Alt+a"
SHORTCUT_DONE="Alt+d"
SHORTCUT_EDIT="Alt+e"
SHORTCUT_SWITCH="Alt+Tab"
SHORTCUT_TERM="Alt+t"
SHORTCUT_FILTERS="Alt+p"
SHORTCUT_CLEAR="Alt+c"
SHORTCUT_HELP="Alt+h"

EDITOR='gedit'

ROFI_BIN="$(command -v rofi)"
TODO_BIN=$(command -v todo-txt || command -v todo.sh)

readonly PROGNAME=$(basename $0)

if [[ -z "$ROFI_BIN" ]]; then
    echo "Missing rofi, please install it !"
    exit 1
fi

if [[ -z "$TODO_BIN" ]]; then
    echo "Missing todo-txt, please install it !"
    exit 1
fi

runrofi () {
    $ROFI_BIN -width 80% -matching glob -tokenize -i -no-levenshtein-sort "$@"
}

runtodo_verbose() {
    $TODO_BIN -p -d "$TODOTXT_CFG_FILE" "$@"
}

runtodo() {
    TODOTXT_VERBOSE=0 runtodo_verbose "$@"
}

list() {
    case $KIND in
      "all")
        runtodo listall;;
      *)
        runtodo list "$@";;
    esac
}

filter_by_priority() {
    IFS=$'\n'
    n=0
    while read LINE; do
        priority=`echo $LINE | grep -oP "^\d+ \K(\([A-Z]\))"`
        priority="${priority:1:1}"
        if [[ $priority == $1 ]]; then
            echo -n "${n},"
        fi

        n=$((n+1))
    done
}

confirm() {
    action=$1
    context=$2
    message="Confirm $action ?"

    # Todo: remove duplicate code...
    if [[ $context ]]; then
        mesg="Item: <span foreground=\"${COLOR_ITEM}\">${context}</span>"
        response=$(echo -e "Yes\nNo" | $ROFI_BIN -lines 2 -u 0 -a 1 -dmenu -mesg "$mesg" -i -p "$message")
    else
        response=$(echo -e "Yes\nNo" | $ROFI_BIN -lines 2 -u 0 -a 1 -dmenu -i -p "$message")
    fi

    if [[ "$response" == "Yes" ]]; then
        return 0;
    else
        return 1;
    fi
}

add() {
    projcon=`getprojconheader`
    new_todo=$(echo -e "< Cancel" | runrofi -lines 1 -dmenu -mesg "New todo
${projcon}" -p "> ")

    if [[ "$new_todo" != "" ]]; then
      runtodo add $new_todo
    fi
}

ere_quote() {
    # Picked from https://stackoverflow.com/a/16951928
    sed 's/[]\.|$(){}?+*^[]/\\&/g' <<< "$*"
}

highlight() {
    # Escape &, <, >
    line=`echo "$1" | sed 's/\&/\&amp;/g' | sed 's/</\&lt;/g; s/>/\&gt;/g;'`

    # Highlight
    WORD_REGEX="[[:alnum:]]+"
    echo "${line}" | sed -r "
        s/^\(([a-zA-Z]+)\) (.*)/${MARKUP_PRIORITY}/g;
        s/(\+${WORD_REGEX})/${MARKUP_PROJECT}/g;
        s/(\@${WORD_REGEX})/${MARKUP_CONTEXT}/g;
        s/(\#${WORD_REGEX})/${MARKUP_TAG}/g;
        s/(due\:[0-9\-]+)/${MARKUP_DUE}/g"
}

unhighlight() {
    # Unescape <, >, &
    line=`echo "$1" | sed 's/\&lt;/</g; s/\&gt;/>/g;' | sed 's/\&amp;/\&/g'`

    UNMARKUP_PRIORITY="${MARKUP_PRIORITY/\\1/([a-zA-Z]+)}"
    UNMARKUP_PRIORITY="${UNMARKUP_PRIORITY/\\2/(.*)}"

    REGEX="([^<]*)"
    UNMARKUP_PROJECT="${MARKUP_PROJECT/\\1/${REGEX}}"
    UNMARKUP_CONTEXT="${MARKUP_CONTEXT/\\1/${REGEX}}"
    UNMARKUP_TAG="${MARKUP_TAG/\\1/${REGEX}}"
    UNMARKUP_DUE="${MARKUP_DUE/\\1/${REGEX}}"

    echo "${line}" | sed -r "
        s/^${UNMARKUP_PRIORITY}/(\1) \2/g;
        s/${UNMARKUP_PROJECT}/\1/g;
        s/${UNMARKUP_CONTEXT}/\1/g;
        s/${UNMARKUP_TAG}/\1/g;
        s/${UNMARKUP_DUE}/\1/g"
}

getprojconheader() {
    listproj=`runtodo listproj | tr '\n' ' '`
    listcon=`runtodo listcon | tr '\n' ' '`

    listproj=`highlight "${listproj}"`
    listcon=`highlight "${listcon}"`

    echo "Projects: ${listproj}
Context: ${listcon}"
}

getlinenumber() {
    line=`unhighlight "$1"`
    line=`ere_quote "${line}"`
    echo `runtodo ls | grep -P "\d+ ${line}$" | awk '{print $1}'`
}

extractcontent() {
    line="$1"
    if [[ "${line:0:1}" == '(' ]]; then
        echo "$line" | sed 's/\([^ ]*\) \(.*\)/\2/'
    else
        echo "$line"
    fi
}

edit() {
    lineno=$1
    current_line=`unhighlight "$2"`
    current_line=`extractcontent "${current_line}"`
    projcon=`getprojconheader`
    todo=$(runrofi -lines 0 -dmenu -mesg "Edit todo
${projcon}" -p "> " -filter "$current_line")
    if [[ -n "$todo" ]]; then
        runtodo replace "$lineno" "$todo"
    fi
}

editpriority() {
    lineno=$1
    current_line="$2"
    priority=$(for letter in {A..Z}; do echo "$letter"; done| runrofi -dmenu -mesg "Item: <span foreground=\"${COLOR_ITEM}\">${current_line}</span>" -p "> ")
    runtodo pri "$lineno" "$priority"
}

option() {
    current_line="$1"
    while true
    do
        if [[ ${current_line:0:1} == 'x' ]]; then
            selection=$(echo -e "Not implemented" | runrofi -sep "|" -kb-accept-entry "Return" -mesg "Item: ${current_line}" -dmenu -p "Action")
            break
        else
            selection=$(echo -e "1. Mark Done|2. Edit|3. Edit priority|4. Remove priority|5. Delete" | runrofi -lines 5 -sep "|" -u 4 -a 0 -kb-accept-entry "Return" -mesg "Item: ${current_line}" -dmenu -p "Action")
            lineno=`getlinenumber "$current_line"`

            case "${selection:0:1}" in
              "1")
                confirm "mark as done" "$current_line" && runtodo do $lineno && break;;
              "2")
                edit $lineno "$current_line" && break;;
              "3")
                editpriority $lineno "$current_line" && break;;
              "4")
                confirm "remove priority" "$current_line" && runtodo depri $lineno && break;;
              "5")
                confirm "deletion" "$current_line" && runtodo -f del $lineno && break;;
              *)
                break;;
            esac
        fi
    done
}

savefilter() {
    echo "# File used by todofi.sh" > $FILTER_FILE
    echo "FILTER=\"$FILTER\"" >> $FILTER_FILE
}

loadfilter() {
    [ -f $FILTER_FILE ] && source $FILTER_FILE
}

termfilter() {
    HEADER="Filter tasks by using term
Ex:
  * Display only tasks that contains FOO: <span color='${COLOR_EXAMPLE}'>FOO</span>
  * Display only tasks that contains FOO or BAR: <span color='${COLOR_EXAMPLE}'>FOO|BAR</span>
  * Hide tasks that do not contains FOO: <span color='${COLOR_EXAMPLE}'>-FOO</span>"
    FILTER=$(runrofi -format f -lines 0 -kb-accept-entry "Return" -mesg "${HEADER}" -dmenu -p "Term" -filter "$FILTER")

    savefilter
}

listprojectandcontext() {
    HEADER="Select a project (+) or context (@) that will serve as a persistent filter"

    listproj=`runtodo listproj`
    listcon=`runtodo listcon`
    selection=$(echo -e "All\n""${listproj}\n${listcon}\n${listprojno}\n${listconno}" | runrofi -kb-accept-entry "Return" -mesg "${HEADER}" -dmenu -p "Action")

    if [[ $selection == 'All' ]]; then
        FILTER=""
    elif [[ -n $selection ]]; then
        FILTER="$selection"
    fi

    savefilter
}

formatline() {
    while read LINE; do
        LINE=`echo "${LINE}" | sed -r 's/[0-9]*\ (.*)/\1/g'`
        highlight "${LINE}"
    done
}

linescount() {
    count="$1"
    if [[ $LINES_MODE == 'auto' ]]; then
        count=$(($count < $LINES_MIN ? $LINES_MIN : $count))
        count=$(($count > $LINES_MAX ? $LINES_MAX : $count))
        echo "-lines $count"
    fi
}

TODOFISH_HEADER="<span color=\"${COLOR_TITLE}\">Todofi.sh</span>"

config() {
    HELP="${TODOFISH_HEADER} - Configuration files"

    source $TODOTXT_CFG_FILE

    selection=$(
        echo -e "1. Open todo.txt config file (${TODOTXT_CFG_FILE})|2. Open todofish config file (${CONFIG_FILE})|3. Open current filter file (${FILTER_FILE})" | \
        runrofi -sep "|" -lines 3 -u 0 -a 1 -kb-accept-entry "Return" -mesg "${HELP}" -dmenu -p "Action"
    )
    val=$?

    if [[ $val -eq 0 ]]; then
        case "${selection:0:1}" in
          "1")
            $EDITOR $TODOTXT_CFG_FILE;;
          "2")
            $EDITOR $CONFIG_FILE;;
          "3")
            $EDITOR $FILTER_FILE;;
          *)
            exit;;
        esac
    fi
}

help() {
    HELP="${TODOFISH_HEADER} - Version ${VERSION} - Charles Rincheval, April 2021
--
* Add todo <span color='${COLOR_SHORTCUT}'>${SHORTCUT_NEW}</span>
* Mark as done <span color='${COLOR_SHORTCUT}'>${SHORTCUT_DONE}</span>
* Edit <span color='${COLOR_SHORTCUT}'>${SHORTCUT_EDIT}</span>
* Switch Active / Done <span color='${COLOR_SHORTCUT}'>${SHORTCUT_SWITCH}</span>
* Filter: Create a filter term <span color='${COLOR_SHORTCUT}'>${SHORTCUT_TERM}</span> / Choose from list <span color='${COLOR_SHORTCUT}'>${SHORTCUT_FILTERS}</span> / Clear <span color='${COLOR_SHORTCUT}'>${SHORTCUT_CLEAR}</span>
--
Todo.txt format: https://github.com/todotxt/todo.txt"

    source $TODOTXT_CFG_FILE

    selection=$(
        echo -e "1. Archive|2. Deduplicate|3. Report|4. Open todo.txt (${TODO_FILE})|5. Open done.txt (${DONE_FILE})|6. See configuration files" | \
        runrofi -sep "|" -lines 6 -u 0 -a 1 -kb-accept-entry "Return" -mesg "${HELP}" -dmenu -p "Action"
    )
    val=$?

    if [[ $val -eq 0 ]]; then
        result=""
        case "${selection:0:1}" in
          "1")
            confirm "archive" && result=`runtodo_verbose archive`;;
          "2")
            confirm "deduplicate" && result=`runtodo deduplicate`;;
          "3")
            confirm "report" && result=`runtodo report`;;
          "4")
            $EDITOR $TODO_FILE;;
          "5")
            $EDITOR $DONE_FILE;;
          "6"):
            config;;
          *)
            exit;;
        esac

        if [[ "$result" ]]; then
            $ROFI_BIN -e "$result"
        fi
    fi
}

main() {
    if [[ $FILTER_ARG ]]; then
        FILTER=$FILTER_ARG
    else
        loadfilter
    fi

    while true
    do
        escaped_filter=`echo "$FILTER" | sed -e 's=|=\\\|=g'`
        list=`list $escaped_filter`
        list=${list//\\/\\\\}
        high=`echo "$list" | filter_by_priority A`
        medium=`echo "$list" | filter_by_priority B`

        count=0
        if [[ "$list" ]]; then
            count=`echo "$list" | wc -l`
        fi

        count_string="<span color=\"${COLOR_INFO}\">${count}</span>"
        if [[ "$escaped_filter" ]]; then
            countall=`runtodo list | wc -l`
            count_string="${count_string} displayed / <span color=\"${COLOR_INFO}\">${countall}</span> item(s)"
        else
            count_string="${count_string} item(s)"
        fi

        current_filter=""
        if [[ $FILTER ]]; then
            current_filter="- Current filter is <span color=\"${COLOR_INFO}\">${FILTER}</span>"
        fi

        HEADER="${TODOFISH_HEADER} - <span color='${COLOR_SHORTCUT}'>${SHORTCUT_HELP}</span> for help - $count_string $current_filter"

        selection=$( \
            echo -E "${list}" | \
            formatline | \
            runrofi `linescount $count` -kb-custom-1 "${SHORTCUT_NEW}" \
                                        -kb-custom-2 "${SHORTCUT_DONE}" \
                                        -kb-custom-3 "${SHORTCUT_EDIT}" \
                                        -kb-custom-4 "${SHORTCUT_FILTERS}" \
                                        -kb-custom-5 "${SHORTCUT_CLEAR}" \
                                        -kb-custom-6 "${SHORTCUT_SWITCH}" \
                                        -kb-custom-7 "${SHORTCUT_HELP}" \
                                        -kb-custom-8 "${SHORTCUT_TERM}" \
                                        -kb-accept-entry "Return" \
                                        -markup-rows \
                                        -u "${high}" -a "${medium}" -mesg "${HEADER}" -dmenu -p "Filter")
        val=$?
        lineno=`getlinenumber "$selection"`

        if [[ $val -eq 0 ]]; then
            if [[ $lineno ]]; then
                option "$selection"
            else
                echo "No line number for '${selection}' !"
                exit
            fi
        elif [[ $val -eq 10 ]]; then
            add
        elif [[ $val -eq 12 ]]; then
            edit $lineno "$selection"
        elif [[ $val -eq 11 ]]; then
            confirm "mark as done" "$selection" && runtodo do "$lineno"
        elif [[ $val -eq 17 ]]; then
            termfilter
        elif [[ $val -eq 13 ]]; then
            listprojectandcontext
        elif [[ $val -eq 14 ]]; then
            FILTER=""
            savefilter
        elif [[ $val -eq 15 ]]; then
            if [[ $KIND == 'all' ]]; then
                KIND=""
            else
                KIND="all"
            fi
            echo "kind is $KIND"
        elif [[ $val -eq 16 ]]; then
            help
        elif [[ $val -ne 1 ]]; then
            echo "Value '$val' not handled !"
            exit
        else
            exit
        fi
    done
}

usage() {
    cat <<- EOF
usage: $PROGNAME options

Todo-txt + Rofi = Todofi.sh
Handle your todo-txt tasks directly from Rofi

OPTIONS:
 -a             Open in add mode
 -f filter      Filter applied on tasks
 -F filename    Filter file (read and write filter on this file)
 -c filename    Config file
 -d filename    Todo.txt config file
EOF
}

if [[ -e $CONFIG_FILE ]]; then
    source $CONFIG_FILE
fi

while getopts "h?af:F:c:d:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0;;
    a)
        ADD_MODE=true;;
    f)
        FILTER_ARG=$OPTARG;;
    F)
        FILTER_FILE=$OPTARG;;
    c)
        CONFIG_FILE=$OPTARG
        source $CONFIG_FILE;;
    d)
        TODOTXT_CFG_FILE=$OPTARG;;
    esac
done

if [[ $ADD_MODE ]]; then
    add
else
    main
fi
