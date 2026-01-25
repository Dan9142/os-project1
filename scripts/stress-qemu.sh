#!/bin/bash

# must do this 
# https://github.com/ros2/ros2/issues/1406
unset GTK_PATH

KERNEL=./kernel/kernel8-rpi3qemu.img

# --- run qemu for 20 times, each 3 secs, then kill. 
# collect all logs (stdout, err). then search for "Segfault"

LOG_FILE="/tmp/qemu-out.log"
> "$LOG_FILE"  # Clear the log file initially

# Loop 20 times
for i in {1..20}; do
    echo "Iteration $i" | tee -a "$LOG_FILE"

    # Start QEMU, redirecting both stdout and stderr to the log file
    /home/student/qemu-9.1.1/build/qemu-system-aarch64 \
    -M raspi3b \
    -kernel ${KERNEL} -serial null -serial mon:stdio \
    -d int -D qemu.log >> "$LOG_FILE" 2>&1 &

    # Give QEMU some time to run
    sleep 2 

    # Kill the QEMU process forcefully
    killall -9 qemu-system-aarch64 >> "$LOG_FILE" 2>&1
done

# Search for "Segfault" (or segfault, case insensitive) in the log and print the count of instances found
SEGFAULT_COUNT=$(grep -ic "Segfault" "$LOG_FILE")
echo "Number of 'Segfault' instances found: $SEGFAULT_COUNT"