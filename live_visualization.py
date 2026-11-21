import pyvisa
import matplotlib.pyplot as plt
import numpy as np
import time

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# 1. Connect Keithley via USB and find this ID in NI-MAX or standard Device Manager
#    It usually looks like: 'USB0::0x05E6::0x2450::04491080::INSTR'
RESOURCE_ID = 'USB0::0x05E6::0x2450::04668307::INSTR' 

# Measurement Settings
V_MIN = -3.0
V_MAX = 3.0
STEPS = 100       # More steps = smoother curve but slower
COMPLIANCE = 0.01 # 10mA

# ==============================================================================
# REAL-TIME PLOTTING CLASS
# ==============================================================================
class RealTimePlot:
    def __init__(self):
        self.fig, self.ax = plt.subplots()
        self.ax.set_title("Live HZO Ferroelectric Hysteresis")
        self.ax.set_xlabel("Voltage (V)")
        self.ax.set_ylabel("Current (A)")
        self.ax.grid(True)
        
        # We use two lines: one for the "trace" and one for the "current point"
        self.line, = self.ax.plot([], [], 'b-', alpha=0.6, label='History')
        self.point, = self.ax.plot([], [], 'ro', label='Current')
        self.ax.legend()
        
        self.x_data = []
        self.y_data = []
        
        # Pre-set axis limits so the plot doesn't jump around
        self.ax.set_xlim(V_MIN - 0.5, V_MAX + 0.5)
        self.ax.set_ylim(-1e-4, 1e-4) # Auto-scale later if needed

    def update(self, v, i):
        self.x_data.append(v)
        self.y_data.append(i)
        
        self.line.set_data(self.x_data, self.y_data)
        self.point.set_data([v], [i])
        
        # Dynamic Y-Axis Scaling
        if abs(i) > self.ax.get_ylim()[1]:
            self.ax.set_ylim(-abs(i)*1.2, abs(i)*1.2)
            
        plt.pause(0.001) # This pause forces the GUI to update

# ==============================================================================
# INSTRUMENT CONTROL
# ==============================================================================
def run_live_measurement():
    rm = pyvisa.ResourceManager()
    
    try:
        # Open Connection
        smu = rm.open_resource(RESOURCE_ID)
        print(f"Connected to: {smu.query('*IDN?')}")
        
        # Reset & Setup
        smu.write('*RST')
        smu.write('ROUT:TERM REAR')         # Force Rear Terminals
        smu.write('SOUR:FUNC VOLT')
        smu.write('SOUR:VOLT:RANG 20')
        smu.write(f'SOUR:VOLT:ILIM {COMPLIANCE}')
        smu.write('SENS:FUNC "CURR"')
        smu.write('SENS:CURR:RANG:AUTO ON') # Auto-range for best resolution
        smu.write('OUTP ON')
        
        # Generate Voltage Sweep Array (0 -> Max -> Min -> 0)
        # Hysteresis loop shape
        sweep_up = np.linspace(0, V_MAX, int(STEPS/4))
        sweep_down = np.linspace(V_MAX, V_MIN, int(STEPS/2))
        sweep_back = np.linspace(V_MIN, 0, int(STEPS/4))
        voltages = np.concatenate([sweep_up, sweep_down, sweep_back])
        
        # Start Plotting
        live_plot = RealTimePlot()
        plt.show(block=False) # Show window without blocking code
        
        print("Starting Sweep... (Look at the Figure Window)")
        
        for v in voltages:
            # 1. Set Voltage
            smu.write(f'SOUR:VOLT {v}')
            
            # 2. Measure (Read)
            # The Keithley returns string like "+1.234E-06", we convert to float
            current = float(smu.query('MEAS:CURR?'))
            
            # 3. Update VS Code Plot
            live_plot.update(v, current)
            
            # 4. Save to file if you want (optional)
            # with open("live_data.csv", "a") as f:
            #    f.write(f"{v},{current}\n")

    except Exception as e:
        print(f"Error: {e}")
        print("Check your Resource ID (e.g., USB0::...)")
        
    finally:
        # Safety Shutdown
        try:
            smu.write('OUTP OFF')
            smu.close()
            print("Measurement Finished. Output OFF.")
        except:
            pass
        plt.show() # Keep plot open at end

if __name__ == "__main__":
    run_live_measurement()