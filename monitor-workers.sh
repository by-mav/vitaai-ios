#!/bin/bash
# Monitor worker activity by watching file changes
cd /Users/mav/vitaai-ios

echo "══════════════════════════════════════"
echo "  SWIFT LEAD — Worker Monitor"  
echo "══════════════════════════════════════"
echo ""

while true; do
    echo "--- $(date +%H:%M:%S) ---"
    
    # Count active claude processes
    PROCS=$(ps aux | grep "claude" | grep -E "s0[0-9]{2}" | grep -v grep | wc -l | tr -d ' ')
    echo "Claude processes: $PROCS"
    
    # Show recently modified files
    RECENT=$(find VitaAI -name "*.swift" -mmin -1 2>/dev/null)
    if [ -n "$RECENT" ]; then
        echo "Files changed (last 60s):"
        echo "$RECENT" | while read f; do echo "  ✏️  $f"; done
    else
        echo "No changes in last 60s"
    fi
    
    echo ""
    sleep 15
done
