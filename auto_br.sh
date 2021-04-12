#!/bin/bash

VIDEO_DEV="/dev/video0"
BACKLIGHT_TYPE="intel_backlight"
DIR="/sys/class/backlight/$BACKLIGHT_TYPE"

OUT="$DIR/brightness"

ACTUAL_BR="$DIR/actual_brightness"

MIN=90
MAX=$( cat "$DIR/max_brightness" )

MIN_AMBIENT_DIFF=16

STEPS=100		# Count of steps during smooth brightness change (more - smoother) 
STEP_DELAY=0.01		# Pause between steps
PAUSE=2			# Additional pause after brightess change

CHECK_SCREEN_STATE=1

# Note that overall pause between ambient measures will be 
# STEPS * STEP_DELAY + PAUSE

RANGE=$(( $MAX - $MIN ))

last_ambient=0

while true
do  
    sleep $PAUSE

    if (( $CHECK_SCREEN_STATE )); then
        real_brightness=$( cat "$ACTUAL_BR" )
        if ([ $real_brightness -eq 0 ]); then
            echo "Screen is off, skipping all work"
            continue
        fi
    fi

    ambient=$( ffmpeg -i $VIDEO_DEV -vf scale=1:1 -pix_fmt gray -f rawvideo -frames:v 1 -v quiet pipe:1 | od -t u | sed 's/000000[01]\s*//')
    ambient_diff=$(( $last_ambient - $ambient ))

    echo "Ambient value: $ambient"
    echo "Ambient diff ${ambient_diff#-}"

    if ([ ${ambient_diff#-} -lt $MIN_AMBIENT_DIFF ]); then
        echo "Skiping change"
        continue
    fi

    last_ambient=$ambient

    curr_brightness=$( cat $OUT )

    new_brightness=$(( $MIN + $RANGE * $ambient / 255 ))

    incr=$(( ($new_brightness - $curr_brightness) / $STEPS ))

    if ([ $incr -eq 0 ]); then
        incr=$(( $new_brightness > $curr_brightness ? 1 : -1 ))
    fi

    for br in $(seq $curr_brightness $incr $new_brightness)
    do  
        echo $br >> "$OUT"
        sleep $STEP_DELAY
    done

    echo $new_brightness >> "$OUT"
    echo "Brightness set: $new_brightness"

done

#####
#####
#####