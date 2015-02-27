#!/bin/bash

# Assign all interrupts and processes on the sytem to low-numbered CPUs and
# assign the VCPU thread to high-numbered CPUs.

# Relies on starting QEMU with a qmp socket in /var/run/qmp, like this:
#   qemu-system-aarch64 -qmp unix:/var/run/qmp,server,nowait

# Get number of cores
NCORES=`getconf _NPROCESSORS_ONLN`

VCPU0_MASK=`printf '%x' $(( 0x1 << ($NCORES - 2) ))`
VCPU1_MASK=`printf '%x' $(( 0x2 << ($NCORES - 2) ))`
SYS_MASK=`printf '%x' $(( ( 1 << ($NCORES - 2)) - 1 ))`

echo "QEMU VCPU threads will be assigned to:"
echo "CPU0: 0x$VCPU0_MASK"
echo "CPU1: 0x$VCPU1_MASK"
echo "All other processes and interrupts will be assigned to: 0x$SYS_MASK"

# Assign all interrupts to SYS_MASK
for IRQDIR in `find /proc/irq/ -maxdepth 1 -mindepth 1 -type d`
do
	echo $SYS_MASK > $IRQDIR/smp_affinity >/dev/null 2>&1
done

# Set the CPU affinity off all processes in the system to SYS_MASK
for PID in `ps -eLf | awk '{ print $4 }'`
do
	taskset -a -p 0x$SYS_MASK $PID >/dev/null 2>&1
done

# Set the CPU affinity of the QEMU VCPU threads to the remaining two CPUs
PID0=`./qmp-cpus -s /var/run/qmp | awk '{ print $3 }' | head -n 1`
PID1=`./qmp-cpus -s /var/run/qmp | awk '{ print $3 }' | tail -n 1`
taskset -p 0x$VCPU0_MASK $PID0
taskset -p 0x$VCPU1_MASK $PID1

# All set
