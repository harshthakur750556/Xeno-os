#!/usr/bin/env python3
import sys
import os
import unittest

def main():
    live_mode = False
    
    for arg in sys.argv[1:]:
        if arg in ("-l", "--live"):
            live_mode = True
        elif arg in ("-s", "--simulation"):
            live_mode = False
        elif arg in ("-h", "--help"):
            print("Usage: python3 run_tests.py [options]")
            print("Options:")
            print("  -l, --live         Run tests in Live Mode against actual desktop shell components")
            print("  -s, --simulation   Run tests in Simulation Mode using background mock simulator (default)")
            print("  -h, --help         Display this help message")
            sys.exit(0)
            
    if live_mode:
        print("======================================================================")
        print("RUNNING XENO OS E2E TEST SUITE IN LIVE MODE")
        print("======================================================================")
        os.environ["XENO_E2E_LIVE"] = "1"
    else:
        print("======================================================================")
        print("RUNNING XENO OS E2E TEST SUITE IN SIMULATION MODE")
        print("======================================================================")
        os.environ["XENO_E2E_LIVE"] = "0"
        
    # Configure path to include project root
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    sys.path.insert(0, project_root)
    
    from desktop.env import init_qt_environment
    init_qt_environment()
    
    # Discover and run tests
    loader = unittest.TestLoader()
    suite = loader.discover(start_dir=os.path.dirname(__file__), pattern="test_*.py")
    
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    if result.wasSuccessful():
        print("\nAll E2E tests passed successfully.")
        sys.exit(0)
    else:
        print(f"\nTest execution failed: {len(result.failures)} failures, {len(result.errors)} errors.")
        sys.exit(1)

if __name__ == "__main__":
    main()
