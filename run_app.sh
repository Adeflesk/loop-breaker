#!/bin/zsh

# --- 1. Colors for pretty logs ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "${BLUE}🌀 Starting LoopBreaker Stack on M3...${NC}"

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