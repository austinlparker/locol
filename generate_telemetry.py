#!/usr/bin/env python3
import subprocess
import time
import sys
import signal
import argparse

def run_otelgen(endpoint="localhost:4317", rate=5, duration=None):
    """
    Run otelgen to generate telemetry data.
    
    Args:
        endpoint (str): The OTLP endpoint to send data to
        rate (int): Rate in seconds between data generation
        duration (int): Optional duration in seconds to run the generator
    """
    base_cmd = [
        "otelgen",
        "--otel-exporter-otlp-endpoint", endpoint,
        "--rate", str(rate),
        "--service-name", "locol-test-generator",
        "--insecure"
    ]
    
    if duration:
        base_cmd.extend(["--duration", str(duration)])
    
    # Define commands for each telemetry type
    telemetry_commands = {
        "traces": ["traces", "multi"],
        "metrics": ["metrics", "sum"],  # Using sum metrics as an example
        "logs": ["logs", "multi"]
    }
    
    # Run each type of telemetry in parallel
    processes = []
    try:
        for telemetry_type, cmd_args in telemetry_commands.items():
            cmd = base_cmd + cmd_args
            print(f"Starting {telemetry_type} generator: {' '.join(cmd)}")
            process = subprocess.Popen(cmd)
            processes.append(process)
        
        def signal_handler(signum, frame):
            print("\nStopping telemetry generation...")
            for p in processes:
                p.terminate()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        
        # Wait for all processes
        for p in processes:
            p.wait()
            
    except FileNotFoundError:
        print("Error: otelgen not found. Please install it with:")
        print("go install github.com/krzko/otelgen@latest")
        sys.exit(1)
    except Exception as e:
        print(f"Error running otelgen: {e}")
        sys.exit(1)
    finally:
        # Cleanup any remaining processes
        for p in processes:
            try:
                p.terminate()
            except:
                pass

def main():
    parser = argparse.ArgumentParser(description='Generate OpenTelemetry data using otelgen')
    parser.add_argument('--endpoint', default='localhost:4317',
                      help='OTLP endpoint (default: localhost:4317)')
    parser.add_argument('--rate', type=int, default=5,
                      help='Rate in seconds between data generation (default: 5)')
    parser.add_argument('--duration', type=int,
                      help='Duration in seconds to run the generator (default: run indefinitely)')
    
    args = parser.parse_args()
    
    print(f"Starting telemetry generation...")
    print(f"Endpoint: {args.endpoint}")
    print(f"Rate: {args.rate} seconds")
    if args.duration:
        print(f"Duration: {args.duration} seconds")
    print("\nPress Ctrl+C to stop")
    
    run_otelgen(args.endpoint, args.rate, args.duration)

if __name__ == "__main__":
    main() 