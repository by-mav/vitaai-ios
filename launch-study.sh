#!/bin/bash
cd /Users/mav/vitaai-ios
clear
PROMPT=$(cat /Users/mav/vitaai-ios/prompts/swift-study.md)
exec claude -p --dangerously-skip-permissions "$PROMPT"
