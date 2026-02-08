from main import db_manager

def run_simulation():
    print("🚀 Starting Behavioral Loop Simulation...")
    
    # Sequence: 3 entries of the same state should trigger "High Risk"
    test_sequence = ["Stress", "Stress", "Stress"]
    
    for i, state in enumerate(test_sequence):
        risk, is_loop = db_manager.log_and_analyze(state, confidence=0.95)
        print(f"Entry {i+1}: Node={state} | Risk={risk} | LoopDetected={is_loop}")
        
    if risk == "High" and is_loop:
        print("\n✅ TEST PASSED: Circuit Breaker triggered successfully.")
    else:
        print("\n❌ TEST FAILED: Logic did not detect the stagnation.")

if __name__ == "__main__":
    run_simulation()