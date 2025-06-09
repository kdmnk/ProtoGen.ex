#!/bin/bash
PROJECT_DIR="/Users/kdmnk/Projects/erlang-with-mcrl2-gen/im/generated/lambdaDaysDemo"

for i in {1..3}; do
  osascript -e "tell application \"Terminal\" to do script \" cd $PROJECT_DIR && 
    iex --name node$i@127.0.0.1 -S mix run -e 'DemoNodeApi.start()'\""
done