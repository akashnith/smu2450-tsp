-- HODGKIN-HUXLEY INSPIRED ACTION POTENTIAL
-- Corrected for Keithley 2450

reset()
errorqueue.clear()

if smu.terminals then
    smu.terminals = smu.TERMINALS_REAR
end

-- ===== HH PARAMETERS =====
local stimulus_voltage = 2.0       -- Suprathreshold stimulus (V)
local stimulus_width = 20e-3       -- 20ms stimulus
local read_voltage = 0.1           -- Read voltage (V)
local sampling_interval = 5e-3     -- 5ms sampling
local compliance_depol = 100e-6    -- Depolarization compliance
local compliance_repol = 100e-3    -- Repolarization compliance

-- ===== DATA FILE =====
local filename = "/usb1/hh_action_potential.csv"
local file = io.open(filename, "w")
if not file then
    -- Fallback if USB not found
    print("Warning: USB not found, printing to screen only.")
else
    file:write("Time_ms,Conductance_uS,Phase\n")
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.nplc = 0.01
smu.source.output = smu.ON

print("Hodgkin-Huxley Action Potential Emulation")
print("Time(ms), Conductance(uS), Phase")

local current_time = 0

-- PHASE 1: RESTING STATE
smu.source.ilimit.level = compliance_repol
smu.source.level = -1.5
delay(0.2)
smu.source.level = 0
delay(0.1)

-- Measure resting potential (50ms)
for i = 1, 50 do
    smu.source.level = read_voltage
    delay(0.0005) -- Wait for settling
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6
    smu.source.level = 0
    
    local line = string.format("%.2f,%.6f,RESTING", current_time, g)
    print(line)
    if file then file:write(line .. "\n") end
    
    current_time = current_time + (sampling_interval * 1000)
    delay(sampling_interval)
end

-- PHASE 2: DEPOLARIZATION (RISING PHASE)
print("--- Depolarization ---")

-- Apply Stimulus
smu.source.ilimit.level = compliance_depol
smu.source.level = stimulus_voltage
delay(stimulus_width)
smu.source.level = 0

-- Measure (100ms)
for i = 1, 100 do
    smu.source.ilimit.level = 100e-3
    smu.source.level = read_voltage
    delay(0.0005)
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6
    smu.source.level = 0
    
    local phase = "DEPOLARIZATION"
    if i > 50 then phase = "PEAK" end
    
    local line = string.format("%.2f,%.6f,%s", current_time, g, phase)
    print(line)
    if file then file:write(line .. "\n") end
    
    current_time = current_time + (sampling_interval * 1000)
    delay(sampling_interval)
end

-- PHASE 3: REPOLARIZATION (FALLING PHASE)
print("--- Repolarization ---")

-- Apply Hyperpolarizing Pulse
smu.source.ilimit.level = compliance_repol
smu.source.level = -1.0
delay(50e-3)
smu.source.level = 0

-- Measure (150ms)
for i = 1, 150 do
    smu.source.level = read_voltage
    delay(0.0005)
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6
    smu.source.level = 0
    
    local phase = "REPOLARIZATION"
    if i > 100 then phase = "HYPERPOLARIZATION" end
    
    local line = string.format("%.2f,%.6f,%s", current_time, g, phase)
    print(line)
    if file then file:write(line .. "\n") end
    
    current_time = current_time + (sampling_interval * 1000)
    delay(sampling_interval)
end

-- PHASE 4: REFRACTORY PERIOD
print("--- Refractory ---")

-- Measure (200ms) - FIX: Use Integer Modulo
for i = 1, 200 do
    smu.source.level = read_voltage
    delay(0.0005)
    local amps = smu.measure.read()
    local g = (amps / read_voltage) * 1e6
    smu.source.level = 0
    
    local line = string.format("%.2f,%.6f,REFRACTORY", current_time, g)
    
    -- 2. FIX: Print every 10th point using standard math
    if math.mod(i, 10) == 0 then
        print(line)
    end
    
    if file then file:write(line .. "\n") end
    
    current_time = current_time + (sampling_interval * 1000)
    delay(sampling_interval)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then file:close() end
print("Emulation Complete")