#!/bin/bash
cd /Users/mav/vitaai-ios
for i in 1 2 3 4; do
  tmux send-keys -t "swift$i" "cd /Users/mav/vitaai-ios && claude --dangerously-skip-permissions -p \"$(cat /Users/mav/vitaai-ios/prompts/swift$i.md)\"" Enter
  sleep 1
done
echo "All 4 launched"
