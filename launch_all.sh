#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Launching LoopBreaker AI Stack...${NC}"

# 1. Start Ollama (Check if running, if not start it)
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${GREEN}➔ Starting Ollama AI...${NC}"
    ollama serve &
    sleep 2
else
    echo -e "${BLUE}➔ Ollama is already running.${NC}"
fi

# 2. Start Neo4j (Assumes Homebrew install)
echo -e "${GREEN}➔ Starting Neo4j Graph Database...${NC}"
brew services start neo4j
sleep 5

# 3. Start FastAPI Backend
echo -e "${GREEN}➔ Starting FastAPI Backend...${NC}"
cd backend
source venv/bin/activate
uvicorn main:app --reload &
BACKEND_PID=$!
cd ..

# 4. Start Flutter Frontend
echo -e "${GREEN}➔ Launching Flutter Web...${NC}"
cd frontend
flutter run -d chrome &
FLUTTER_PID=$!

echo -e "${BLUE}✅ All systems online. Press Ctrl+C to stop all services.${NC}"

# Handle Shutdown
trap "kill $BACKEND_PID $FLUTTER_PID; brew services stop neo4j; echo -e '\n${BLUE}🛑 Services stopped.${NC}'; exit" INT
wait