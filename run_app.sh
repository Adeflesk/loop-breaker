#!/bin/zsh

# --- 1. Colors for pretty logs ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}🌀 Starting LoopBreaker Stack on M3...${NC}"

# Backend port to reserve before launch
BACKEND_PORT="${BACKEND_PORT:-8000}"

free_port() {
	local port="$1"
	local pids
	pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)

	if [ -n "$pids" ]; then
		echo "${BLUE}➔ Releasing port $port (PID: $pids)...${NC}"
		kill $pids 2>/dev/null || true
		sleep 1

		pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
		if [ -n "$pids" ]; then
			echo "${BLUE}➔ Force-stopping remaining process(es) on port $port...${NC}"
			kill -9 $pids 2>/dev/null || true
		fi
	fi
}

free_port "$BACKEND_PORT"

# --- 2. Start Backend (FastAPI) in the background ---
echo "${GREEN}➔ Launching Backend (FastAPI)...${NC}"
cd backend
source venv/bin/activate
# Run uvicorn in the background and save its process ID (PID)
python main.py & 
BACKEND_PID=$!
cd ..

# --- 3. Wait for Backend to wake up ---
sleep 2

# --- 4. Start Frontend (Flutter) ---
echo "${GREEN}➔ Launching Frontend (Flutter)...${NC}"
cd frontend
# Using -d macos to run it as a desktop app for speed, 
# or change to 'ios' for the simulator.
flutter run -d chrome

# --- 5. Cleanup when the app closes ---
echo "${BLUE}Stopping Backend (PID: $BACKEND_PID)...${NC}"
kill $BACKEND_PID