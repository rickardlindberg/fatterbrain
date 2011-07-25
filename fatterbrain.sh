#!/bin/bash

initial_state() {
    echo "^"; echo "1"; echo "2"; echo "^";
    echo "v"; echo "3"; echo "4"; echo "v";
    echo "^"; echo "<"; echo ">"; echo "^";
    echo "v"; echo "o"; echo "o"; echo "v";
    echo "o"; echo "_"; echo "_"; echo "o";
}

print_state() {
    put "+-------------+\n"
    for pos in {1..20}; do
        if test $(expr $pos % 4) -eq 1; then put "| "; fi
        read char
        case $char in
            "^") put "/\\ " ;;
            "v") put "\\/ " ;;
            "<") put "<--"  ;;
            ">") put "-> "  ;;
            "1") put "/--"  ;;
            "2") put "-\\ " ;;
            "3") put "\\--" ;;
            "4") put "-/ "  ;;
            "o") put "() "  ;;
            "_") put "   "  ;;
        esac
        if test $(expr $pos % 4) -eq 0; then put "|\n"; fi
    done
    put "+-------------+\n"
}

find_other_state() {
    echo "Level =" $(pwd | tr "/" "\n" | wc -l)
    if has_state_earlier; then
        echo "Backtracking."
        return 1
    fi
    if cat $state_file | is_state_solution; then
        echo "Found solution in state" $(pwd)
        pwd
        return 0
    else
        for pos in {1..20}; do
            char=$(state_at_current $pos)
            case $char in
                "o") move_single $pos ;;
                "^") move_tower $pos ;;
                "<") move_stock $pos ;;
                "1") move_square $pos ;;
            esac
        done
        for dir in sub_*; do
            echo "Making move:"
            (cd $dir && cat $state_file | print_state && find_other_state)
            if test $? -eq 0; then
                return 0
            fi
        done
        return 1
    fi
}

has_state_earlier() {
    file="../$state_file"
    while test -e "$file"; do
        if diff $file $state_file > /dev/null 2>&1; then
            return 0
        fi
        file="../$file"
    done
    return 1
}

state_at_current() {
    cat $state_file | state_at $1
}

move_single() {
    pos=$1
    can_move $pos -1 && single_move_replace -1 o $pos
    can_move $pos  1 && single_move_replace  1 o $pos
    can_move $pos -4 && single_move_replace -4 o $pos
    can_move $pos  4 && single_move_replace  4 o $pos
}

move_tower() {
    top_pos=$1
    bottom_pos=$(expr $1 + 4)
    can_move $top_pos -1 && can_move $bottom_pos -1 && \
        single_move_replace -1 ^ $top_pos v $bottom_pos
    can_move $top_pos 1 && can_move $bottom_pos 1 && \
        single_move_replace  1 ^ $top_pos v $bottom_pos
    can_move $top_pos    -4 && \
        single_move_replace -4 ^ $top_pos v $bottom_pos
    can_move $bottom_pos  4 && \
        single_move_replace  4 v $bottom_pos ^ $top_pos
}

move_stock() {
    left_pos=$1
    right_pos=$(expr $1 + 1)
    can_move $left_pos -1 && single_move_replace -1 "<" $left_pos ">" $right_pos
    can_move $right_pos 1 && single_move_replace  1 ">" $right_pos "<" $left_pos
    can_move $left_pos -4 && can_move $right_pos -4 && \
        single_move_replace -4 "<" $left_pos ">" $right_pos
    can_move $left_pos 4 && can_move $right_pos 4 && \
        single_move_replace 4 "<" $left_pos ">" $right_pos
}

move_square() {
    left_up_pos=$1
    right_up_pos=$(expr $1 + 1)
    left_down_pos=$(expr $1 + 4)
    right_down_pos=$(expr $1 + 5)
    can_move $left_up_pos -1 && can_move $left_down_pos -1 && \
        single_move_replace -1 "1" $left_up_pos "3" $left_down_pos "2" $right_up_pos "4" $right_down_pos
    can_move $right_up_pos 1 && can_move $right_down_pos 1 && \
        single_move_replace 1 "2" $right_up_pos "4" $right_down_pos "1" $left_up_pos "3" $left_down_pos 
    can_move $left_up_pos -4 && can_move $right_up_pos -4 && \
        single_move_replace -4 "1" $left_up_pos "2" $right_up_pos "3" $left_down_pos "4" $right_down_pos
    can_move $left_down_pos 4 && can_move $right_down_pos 4 && \
        single_move_replace 4 "3" $left_down_pos "4" $right_down_pos "1" $left_up_pos "2" $right_up_pos 
}

can_move() {
    pos=$1
    delta=$2
    leftmost $pos && test $delta -eq -1 && return 1
    topmost $pos && test $delta -eq -4 && return 1
    rightmost $pos && test $delta -eq 1 && return 1
    bottommost $pos && test $delta -eq 4 && return 1
    state_empty_at_current $(expr $pos + $delta)
}

state_empty_at_current() {
    cat $state_file | state_empty_at $1
}

state_empty_at() {
    test "$(state_at $1)" = "_"
}

leftmost()   {
    test $(expr $1 % 4) -eq 1
}

rightmost()  {
    test $(expr $1 % 4) -eq 0
}

topmost()    {
    test $1 -gt 0 && test $1 -lt 5
}

bottommost() {
    test $1 -gt 16 && test $1 -lt 21
}

single_move_replace() {
    replace_string=""
    delta=$1
    shift
    num_pieces=$(expr $# / 2)
    for i in $(seq 1 $num_pieces); do
        symbol=$1
        pos=$2
        new_pos=$(expr $pos + $delta)
        shift 2
        replace_string="$replace_string ; s/^$pos $symbol/$pos _/ ; s/^$new_pos _/$new_pos $symbol/"
    done
    replace "$replace_string"
}

replace() {
    if test "$(echo sub_*)" = "sub_*"; then
        largest="0"
    else
        largest=$(echo sub_* | tr " " "\n" | tr "_" " " | awk '{print $2}' | sort -n | tail -n1)
    fi
    new_name="sub_$(expr $largest + 1)"
    mkdir $new_name
    cat $state_file | numbered_state | sed "$1" | awk '{print $2}' > "$new_name/$state_file"
}

state_at() {
    discard_index=1
    while test $discard_index -lt $1; do
        read char
        discard_index=$(expr $discard_index + 1)
    done
    read char
    echo $char
}

put() {
    printf "%b" "$1"
}

is_state_solution() {
    test $(numbered_state | grep "^\(14 1\|15 2\|18 3\|19 4\)" | wc -l) -eq 4
}

numbered_state() {
    awk '{pos++} {print pos " " $0}'
}


state_file="state.txt"
initial_state > $state_file

initial_state | print_state
find_other_state
