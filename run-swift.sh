#!/bin/bash
NUM=$1
cd /Users/mav/vitaai-ios
claude --dangerously-skip-permissions -p "$(cat /Users/mav/vitaai-ios/prompts/swift${NUM}.md)"
