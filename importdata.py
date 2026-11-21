import pyvisa
import time

# --- CONFIGURATION ---
PORT = 'USB0::0x05E6::0x2450::04668307::INSTR' # Find this in NI-MAX or Device Manager
OUTPUT_FILE = 'HfSrTiO2_Data_Laptop.csv'
TSP_FILE = 'newfull.tsp' 

rm = pyvisa.ResourceManager()
try:
    smu = rm.open_resource(PORT)
    smu.timeout = 10000 # 10 seconds
    
    print(f"Connected to SMU. Sending {TSP_FILE}...")

    # Load and send the script
    with open(TSP_FILE, 'r') as f:
        script = f.read()
    
    smu.write(script)

    # Listen for data
    with open(OUTPUT_FILE, 'w') as local_csv:
        print(f"Capturing data to {OUTPUT_FILE}...")
        while True:
            try:
                line = smu.read().strip()
                
                if "DATA," in line:
                    # Remove the prefix and save to CSV
                    clean_data = line.replace("DATA,", "")
                    local_csv.write(clean_data + "\n")
                    print(f"Captured: {clean_data}")
                
                elif "MSG:" in line:
                    print(f"Instrument: {line}")
                
                if "COMPLETE" in line:
                    break
                    
            except pyvisa.VisaIOError:
                # This happens if the instrument stops sending for a moment
                continue

    print("Done! Data is ready in VS Code.")

except Exception as e:
    print(f"Error: {e}")
finally:
    rm.close()
