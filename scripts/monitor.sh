#!/bin/bash
umask 0117

AGENT_HOME=/home/agent-admin/agent-app
AGENT_LOG_DIR=/var/log/agent-app
LOG_FILE=$AGENT_LOG_DIR/monitor.log
APP_NAME=agent-app
PORT=15034
MAX_SIZE=$((10 * 1024 * 1024))
MAX_FILES=10

echo "====== SYSTEM MONITOR RESULT ======"
echo ""
echo "[HEALTH CHECK]"

PID=$(pgrep -f "$AGENT_HOME/$APP_NAME" | tr '\n' ' ')
if [ -z "$PID" ]; then
    echo "Checking process $APP_NAME... [FAIL] Not running"
    exit 1
fi
echo "Checking process $APP_NAME... [OK] (PID: $PID)"

PORT_CHECK=$(ss -tulnp | grep ":$PORT ")
if [ -z "$PORT_CHECK" ]; then
    echo "Checking port $PORT... [FAIL] Not listening"
    exit 1
fi
echo "Checking port $PORT... [OK]"

UFW_STATUS=$(systemctl is-active ufw 2>/dev/null)
if [ "$UFW_STATUS" != "active" ]; then
    echo "[WARNING] Firewall is not active"
fi

echo ""
echo "[RESOURCE MONITORING]"

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2+$4}')
MEM=$(free | grep Mem | awk '{printf "%.1f", $3/$2*100}')
DISK=$(df / | tail -1 | awk '{print $5}' | tr -d '%')

echo "CPU Usage : $CPU%"
echo "MEM Usage : $MEM%"
echo "DISK Used  : $DISK%"

CPU_INT=$(echo $CPU | cut -d'.' -f1)
MEM_INT=$(echo $MEM | cut -d'.' -f1)

if [ "$CPU_INT" -gt 20 ]; then
    echo "[WARNING] CPU threshold exceeded ($CPU% > 20%)"
fi
if [ "$MEM_INT" -gt 10 ]; then
    echo "[WARNING] MEM threshold exceeded ($MEM% > 10%)"
fi
if [ "$DISK" -gt 80 ]; then
    echo "[WARNING] DISK threshold exceeded ($DISK% > 80%)"
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] PID:$PID CPU:$CPU% MEM:$MEM% DISK_USED:$DISK%" >> $LOG_FILE
echo ""
echo "[INFO] Log appended: $LOG_FILE"

if [ -f "$LOG_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$LOG_FILE")
    if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
        if [ -f "$LOG_FILE.$MAX_FILES" ]; then
            rm "$LOG_FILE.$MAX_FILES"
        fi
        for i in $(seq $((MAX_FILES-1)) -1 1); do
            if [ -f "$LOG_FILE.$i" ]; then
                mv "$LOG_FILE.$i" "$LOG_FILE.$((i+1))"
            fi
        done
        mv "$LOG_FILE" "$LOG_FILE.1"
    fi
fi
