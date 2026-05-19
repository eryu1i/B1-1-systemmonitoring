#!/bin/bash

LOG_FILE=/var/log/agent-app/monitor.log

echo "로그 범위:"
echo "시작: $(head -1 $LOG_FILE | grep -oP '\[\K[^\]]+')"
echo "종료: $(tail -1 $LOG_FILE | grep -oP '\[\K[^\]]+')"
echo ""

read -p "시작 (YYYY-MM-DD HH:MM, 엔터시 처음부터): " START
read -p "종료 (YYYY-MM-DD HH:MM, 엔터시 끝까지): " END

if [ -n "$START" ] || [ -n "$END" ]; then
    if [ -n "$START" ] && ! echo "$START" | grep -qP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'; then
        echo "[ERROR] 시작 시간 형식이 잘못됐습니다."
        exit 1
    fi
    if [ -n "$END" ] && ! echo "$END" | grep -qP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'; then
        echo "[ERROR] 종료 시간 형식이 잘못됐습니다."
        exit 1
    fi
    if [ -n "$START" ] && ! date -d "$START" &>/dev/null; then
        echo "[ERROR] 존재하지 않는 날짜입니다."
        exit 1
    fi
    if [ -n "$END" ] && ! date -d "$END" &>/dev/null; then
        echo "[ERROR] 존재하지 않는 날짜입니다."
        exit 1
    fi
    if [ -n "$START" ] && [ -n "$END" ] && [ "$START" \> "$END" ]; then
        echo "[ERROR] 시작 시간이 종료 시간보다 늦습니다."
        exit 1
    fi
    LOG_START=$(head -1 $LOG_FILE | grep -oP '\[\K[^\]]+')
    LOG_END=$(tail -1 $LOG_FILE | grep -oP '\[\K[^\]]+')
    if [ -n "$START" ] && [ "${START}:00" \> "$LOG_END" ]; then
        echo "[ERROR] 로그 범위를 벗어났습니다."
        exit 1
    fi
    if [ -n "$END" ] && [ "${END}:59" \< "$LOG_START" ]; then
        echo "[ERROR] 로그 범위를 벗어났습니다."
        exit 1
    fi
fi

[ -n "$START" ] && START="$START:00"
[ -n "$END" ] && END="$END:59"

if [ -z "$START" ] && [ -z "$END" ]; then
    DATA=$(cat $LOG_FILE)
elif [ -z "$END" ]; then
    DATA=$(awk -v s="$START" '{ts=substr($1,2)" "substr($2,1,length($2)-1); if(ts>=s) print}' $LOG_FILE)
elif [ -z "$START" ]; then
    DATA=$(awk -v e="$END" '{ts=substr($1,2)" "substr($2,1,length($2)-1); if(ts<=e) print}' $LOG_FILE)
else
    DATA=$(awk -v s="$START" -v e="$END" '{ts=substr($1,2)" "substr($2,1,length($2)-1); if(ts>=s && ts<=e) print}' $LOG_FILE)
fi

SAMPLES=$(echo "$DATA" | grep -c "CPU:")
if [ "$SAMPLES" -eq 0 ]; then
    echo "해당 구간에 데이터가 없습니다."
    exit 1
fi

CPU_STATS=$(echo "$DATA" | awk '
BEGIN {min=100; max=0; sum=0; n=0; max_ts=""; min_ts=""}
{
    ts = substr($1,2) " " substr($2,1,length($2)-1)
    for(i=1;i<=NF;i++) {
        if($i ~ /^CPU:/) { v=substr($i,5); gsub(/%/,"",v) }
    }
    sum+=v; n++
    if(v+0>max+0) {max=v; max_ts=ts}
    if(v+0<min+0) {min=v; min_ts=ts}
}
END {printf "  Average : %.1f%%\n  Maximum : %.1f%% at %s\n  Minimum : %.1f%% at %s", sum/n, max, max_ts, min, min_ts}')

MEM_STATS=$(echo "$DATA" | awk '
BEGIN {min=100; max=0; sum=0; n=0; max_ts=""; min_ts=""}
{
    ts = substr($1,2) " " substr($2,1,length($2)-1)
    for(i=1;i<=NF;i++) {
        if($i ~ /^MEM:/) { v=substr($i,5); gsub(/%/,"",v) }
    }
    sum+=v; n++
    if(v+0>max+0) {max=v; max_ts=ts}
    if(v+0<min+0) {min=v; min_ts=ts}
}
END {printf "  Average : %.1f%%\n  Maximum : %.1f%% at %s\n  Minimum : %.1f%% at %s", sum/n, max, max_ts, min, min_ts}')

DISK_STATS=$(echo "$DATA" | awk '
BEGIN {min=100; max=0; sum=0; n=0; max_ts=""; min_ts=""}
{
    ts = substr($1,2) " " substr($2,1,length($2)-1)
    for(i=1;i<=NF;i++) {
        if($i ~ /^DISK_USED:/) { v=substr($i,11); gsub(/%/,"",v) }
    }
    sum+=v; n++
    if(v+0>max+0) {max=v; max_ts=ts}
    if(v+0<min+0) {min=v; min_ts=ts}
}
END {printf "  Average : %.1f%%\n  Maximum : %.1f%% at %s\n  Minimum : %.1f%% at %s", sum/n, max, max_ts, min, min_ts}')

echo "====== STATISTICS REPORT ======"
echo "  [CPU]"
echo "$CPU_STATS"
echo "  [Memory]"
echo "$MEM_STATS"
echo "  [Disk]"
echo "$DISK_STATS"
echo "  [Samples]"
echo "    Data Points: $SAMPLES samples"
