-- Neuromorphic Pulse Measurement - Rear Terminal + Data Save
reset()

-- ===== SELECT REAR TERMINALS FIRST (BEFORE ANY OTHER CONFIG) =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PULSE PARAMETERS =====
local pulse_amplitude = 1.0      -- Voltage amplitude (V)
local pulse_width = 0.001        -- Pulse width (seconds) - 1ms
local pulse_delay = 0.01         -- Delay between pulses (seconds) - 10ms
local base_level = 0.0           -- Base voltage level (V)
local num_pulses = 10            -- Number of pulses
local current_limit = 0.1        -- Current compliance (A)

-- ===== DATA FILE SETUP =====
local filename = "/usb1/neuromorphic_data.csv"  -- Save to USB drive
-- Alternative: use internal memory
-- local filename = "neuromorphic_data.csv"

-- Open file for writing
local file = io.open(filename, "w")
if file then
    file:write("Pulse,Time,Voltage,Current\n")  -- CSV header
else
    print("ERROR: Could not open file for writing")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.readback = smu.ON
smu.source.autorange = smu.ON
smu.source.ilimit.level = current_limit

smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 0.01  -- Fast measurement

-- ===== OUTPUT ON =====
smu.source.output = smu.ON
smu.source.level = base_level
delay(0.1)

print("Starting neuromorphic pulse measurements (REAR terminals)...")
print("Pulse#, Time(s), Voltage(V), Current(A)")

-- ===== PULSE GENERATION =====
for pulse = 1, num_pulses do
    local start_time = os.clock()
    
    -- Apply pulse
    smu.source.level = pulse_amplitude
    delay(pulse_width)
    local i_pulse = smu.measure.read()
    
    -- Return to base level
    smu.source.level = base_level
    
    -- Print and save results
    local data_line = string.format("%d,%.6f,%.3f,%.6e", 
                                     pulse, start_time, pulse_amplitude, i_pulse)
    print(data_line)
    
    if file then
        file:write(data_line .. "\n")
    end
    
    -- Wait before next pulse
    delay(pulse_delay)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("Pulse sequence complete")