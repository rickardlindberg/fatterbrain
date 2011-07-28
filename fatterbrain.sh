#!/bin/bash

STATE_FILE="state.txt"

find_solution_from_begining() {
    cd $(mktemp -d fatterbrain_data_XXXXXXXXXX)
    print_initial_state > $STATE_FILE
    if [[ $1 = "depth" ]]; then
        search_for_solution_depth_first
    elif [[ $1 = "breadth" ]]; then
        search_for_solution_breadth_first
    fi
}

print_initial_state() {
    echo "1 ^";  echo "2 1";  echo "3 2";  echo "4 ^";
    echo "5 v";  echo "6 3";  echo "7 4";  echo "8 v";
    echo "9 ^";  echo "10 <"; echo "11 >"; echo "12 ^";
    echo "13 v"; echo "14 o"; echo "15 o"; echo "16 v";
    echo "17 o"; echo "18 _"; echo "19 _"; echo "20 o";
}

search_for_solution_depth_first() {
    verbose && print_current_state
    echo "Level =" $(pwd | tr "/" "\n" | wc -l)
    if has_state_been_visited; then
        echo "Backtracking."
        return 1
    fi
    if is_current_state_solution; then
        echo "Found solution in state" $(pwd)
        print_solution
        return 0
    else
        create_sub_states
        for dir in sub_*; do
            verbose && echo "Making move:"
            (cd $dir && search_for_solution_depth_first)
            if (($? == 0)); then
                return 0
            fi
        done
        return 1
    fi
}

search_for_solution_breadth_first() {
    root=$(pwd)
    states="$STATE_FILE"
    level=0
    while true; do
        level=$(expr $level + 1)
        echo "At level" $level
        for state in $states; do
            (
                put "."
                state_dir=$(dirname $state)
                cd $state_dir
                if has_state_been_visited; then
                    printf "d"
                    rm -r $root/$state_dir
                    return 1
                elif is_current_state_solution; then
                    echo
                    print_solution
                    return 0
                else
                    create_sub_states
                    return 1
                fi
            )
            if test $? -eq 0; then
                exit 0
            fi
        done
        echo
        states="*/$states"
    done
}

verbose() {
    true
}

has_state_been_visited() {
    previous_state="../$STATE_FILE"
    while [[ -e "$previous_state" ]]; do
        if diff $previous_state $STATE_FILE > /dev/null 2>&1; then
            return 0
        fi
        previous_state="../$previous_state"
    done
    return 1
}

is_current_state_solution() {
    cat $STATE_FILE | (($(grep "^\(14 1\|15 2\|18 3\|19 4\)" | wc -l) == 4))
}

print_solution() {
    current_dir=$(pwd)
    while [[ -e "$STATE_FILE" ]]; do
        print_current_state
        cd ..
    done
    cd "$current_dir"
}

print_current_state() {
    cat $STATE_FILE | awk '{print $2}' | print_state
}

print_state() {
    put "+-------------+\n"
    for pos in {1..20}; do
        if (($pos % 4 == 1)); then put "| "; fi
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
        if (($pos % 4 == 0)); then put "|\n"; fi
    done
    put "+-------------+\n"
}

put() {
    printf "%b" "$1"
}

create_sub_states() {
    move_pieces $(cat $STATE_FILE | grep "^[0-9]* [o^<1]")
}

move_pieces() {
    while (($# != 0)); do
        pos=$1
        char=$2
        shift 2
        case $char in
            "o") move_single $pos ;;
            "^") move_tower $pos ;;
            "<") move_stock $pos ;;
            "1") move_square $pos ;;
        esac
    done
}

move_single() {
    pos=$1
    can_move $pos -1 && move_parts_by_delta -1 o $pos
    can_move $pos  1 && move_parts_by_delta  1 o $pos
    can_move $pos -4 && move_parts_by_delta -4 o $pos
    can_move $pos  4 && move_parts_by_delta  4 o $pos
}

move_tower() {
    top_pos=$1
    ((bottom_pos = $1 + 4))
    can_move $top_pos -1 && can_move $bottom_pos -1 && \
        move_parts_by_delta -1 ^ $top_pos v $bottom_pos
    can_move $top_pos 1 && can_move $bottom_pos 1 && \
        move_parts_by_delta  1 ^ $top_pos v $bottom_pos
    can_move $top_pos    -4 && \
        move_parts_by_delta -4 ^ $top_pos v $bottom_pos
    can_move $bottom_pos  4 && \
        move_parts_by_delta  4 v $bottom_pos ^ $top_pos
}

move_stock() {
    left_pos=$1
    ((right_pos = $1 + 1))
    can_move $left_pos -1 && move_parts_by_delta -1 "<" $left_pos ">" $right_pos
    can_move $right_pos 1 && move_parts_by_delta  1 ">" $right_pos "<" $left_pos
    can_move $left_pos -4 && can_move $right_pos -4 && \
        move_parts_by_delta -4 "<" $left_pos ">" $right_pos
    can_move $left_pos 4 && can_move $right_pos 4 && \
        move_parts_by_delta 4 "<" $left_pos ">" $right_pos
}

move_square() {
    left_up_pos=$1
    ((right_up_pos = $1 + 1))
    ((left_down_pos = $1 + 4))
    ((right_down_pos = $1 + 5))
    can_move $left_up_pos -1 && can_move $left_down_pos -1 && \
        move_parts_by_delta -1 "1" $left_up_pos "3" $left_down_pos "2" $right_up_pos "4" $right_down_pos
    can_move $right_up_pos 1 && can_move $right_down_pos 1 && \
        move_parts_by_delta 1 "2" $right_up_pos "4" $right_down_pos "1" $left_up_pos "3" $left_down_pos 
    can_move $left_up_pos -4 && can_move $right_up_pos -4 && \
        move_parts_by_delta -4 "1" $left_up_pos "2" $right_up_pos "3" $left_down_pos "4" $right_down_pos
    can_move $left_down_pos 4 && can_move $right_down_pos 4 && \
        move_parts_by_delta 4 "3" $left_down_pos "4" $right_down_pos "1" $left_up_pos "2" $right_up_pos 
}

can_move() {
    pos=$1
    delta=$2
    leftmost $pos && (($delta == -1)) && return 1
    topmost $pos && (($delta == -4)) && return 1
    rightmost $pos && (($delta == 1)) && return 1
    bottommost $pos && (($delta == 4)) && return 1
    state_empty_at_current $(($pos + $delta))
}

leftmost() {
    (($1 % 4 == 1))
}

rightmost() {
    (($1 % 4 == 0))
}

topmost() {
    (($1 > 0 && $1 < 5))
}

bottommost() {
    (($1 > 16 && $1 < 21))
}

state_empty_at_current() {
    cat $STATE_FILE | grep "^$1 _" > /dev/null 2<&1
}

move_parts_by_delta() {
    replace_string=""
    delta=$1
    shift
    ((num_parts = $# / 2))
    for i in $(seq 1 $num_parts); do
        symbol=$1
        pos=$2
        ((new_pos = $pos + $delta))
        shift 2
        replace_string="$replace_string ; s/^$pos $symbol/$pos _/ ; s/^$new_pos _/$new_pos $symbol/"
    done
    create_new_state_by_replace "$replace_string"
}

create_new_state_by_replace() {
    state_name=$(generate_new_state_name)
    mkdir $state_name
    cat $STATE_FILE | sed "$1" > "$state_name/$STATE_FILE"
}

generate_new_state_name() {
    if [[ "$(echo sub_*)" = "sub_*" ]]; then
        largest="0"
    else
        largest=$(echo sub_* | tr " " "\n" | tr "_" " " | awk '{print $2}' | sort -n | tail -n1)
    fi
    echo "sub_$(($largest + 1))"
}

find_solution_from_begining $1
