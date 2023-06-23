#!/bin/bash

# Start a VM with 16 cores, treat the cores as four groups of four cores
for i in {0..15}
do
    virsh vcpupin e-vm1 $i $i
done

# Start sysbench on all 16 vcpus for 3 minutes, running in the background
e-vm1 << EOF
    nohup sysbench --threads=16 --time=180 cpu run > pre_prober_sysbench.txt &
EOF

# Wait a bit for sysbench to start
sleep 10

# Start the prober
e-vm1 << EOF
    echo "$(date): Starting prober" >> prober_output.txt
    nohup sudo ./a.out -p 100 -s 1000 -v -i 20 >> prober_output.txt &
EOF

# Initialize competition on physical cores
taskset -c 0-3 sysbench --threads=4 cpu run &
taskset -c 4-7 sysbench --threads=4 cpu run &
taskset -c 4-7 sysbench --threads=4 cpu run &
taskset -c 4-7 sysbench --threads=4 cpu run &

# Wait a minute to let the prober measure
sleep 60

e-vm1 << EOF
    echo "$(date): First minute of measurement finished" >> prober_output.txt
EOF

# Move the fourth group to an empty socket
for i in {12..15}
do
    virsh vcpupin e-vm1 $i $((i + 16))
done

# Wait a minute for prober to measure the new configuration
sleep 60

e-vm1 << EOF
    echo "$(date): Second minute of measurement finished, after moving the fourth group" >> prober_output.txt
EOF

# Change the target latency of the host system
echo 48 | sudo tee /proc/sys/kernel/sched_min_granularity_ns

# Wait for another minute to let the prober measure latency changes
sleep 60

e-vm1 << EOF
    echo "$(date): Third minute of measurement finished, after changing target latency" >> prober_output.txt
EOF

# Stop the prober
e-vm1 << EOF
    sudo pkill -f './a.out -p 100 -s 1000 -v -i 20'
EOF

# Collect the output files from the VM
scp e-vm1:/path/to/pre_prober_sysbench.txt /local/path/on/host/
scp e-vm1:/path/to/prober_output.txt /local/path/on/host/