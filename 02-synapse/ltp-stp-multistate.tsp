-- SIMPLE POTENTIATION/DEPRESSION WITH RETENTION TEST
-- 10 pulses followed by 100s retention measurement
-- Compatible with Keithley 2450 TSP

reset()

-- CONFIGURATION - MODIFY THESE PARAMETERS

-- DEVICE INFO
local device_id = "sample"
local test_type = "potentiation"  -- "potentiation" or "depression"

-- FILE PATH
local filename = "/usb1/my_test_data.csv" -- CORRECT
-- TERMINAL SELECTION
-- NOTE: this script uses smu.terminals; most others here use
-- smu.measure.terminals. Confirm which your firmware accepts.
smu.terminals = smu.TERMINALS_REAR

-- PULSE PARAMETERS
local pulse_voltage = 0.2  -- Pulse voltage (V) - use negative for depression
local pulse_width = 0.005  -- Pulse width (5ms)
local num_pulses = 10  -- Number of pulses
local compliance = 1e-5  -- Current compliance (1mA)

-- READ PARAMETERS
local read_voltage = 0.1  -- Read voltage (100mV)
local read_delay = 0.002  -- Read delay (2ms)

-- RETENTION PARAMETERS
local retention_time = 10  -- Total retention time (100s)
local read_interval = 1  -- Read every 1 second

-- MAIN PROGRAM

print("========================================================================")
print("POTENTIATION/DEPRESSION WITH RETENTION TEST")
print("========================================================================")
print("Device: " .. device_id)
print("Test Type: " .. test_type)
print("Pulse Voltage: " .. tostring(pulse_voltage) .. " V")
print("Number of Pulses: " .. tostring(num_pulses))
print("Retention Time: " .. tostring(retention_time) .. " s")
print("========================================================================")
print("")

-- Configure SMU
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.ilimit.level = compliance

-- Open file
local file = io.open(filename, "w")
if not file then
    print("ERROR: Cannot create file " .. filename)
    print("Check USB drive and try again.")
    return
end

-- Write header
file:write("Phase,Pulse_Number,Time_s,Voltage_V,Current_A,Resistance_Ohm,Conductance_S\n")

print("Starting measurement...")
print("")

-- PHASE 1: POTENTIATION/DEPRESSION (10 PULSES)

print("PHASE 1: Applying " .. tostring(num_pulses) .. " pulses")
print("---")

for pulse = 1, num_pulses do
    -- Apply pulse
    smu.source.output = smu.ON
    smu.source.level = pulse_voltage
    delay(pulse_width)
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    delay(read_delay)
    
    -- Read resistance
    smu.source.output = smu.ON
    smu.source.level = read_voltage
    delay(read_delay)
    local current = smu.measure.read()
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    -- Calculate resistance and conductance
    local resistance = 0
    local conductance = 0
    if math.abs(current) > 1e-12 then
        resistance = read_voltage / current
        conductance = current / read_voltage
    end
    
    -- Time since start (approximate)
    local time_elapsed = pulse * (pulse_width + 2 * read_delay + 0.01)
    
    -- Write to file
    file:write(string.format("Potentiation,%d,%.6e,%.6e,%.6e,%.6e,%.6e\n",
        pulse, time_elapsed, read_voltage, current, resistance, conductance))
    
    print(string.format("  Pulse %d: I = %.3e A, R = %.3e Ω", 
        pulse, current, resistance))
    
    delay(0.01)  -- Brief pause between pulses
end

print("")
print("Potentiation phase complete!")
print("")

-- PHASE 2: RETENTION (100 SECONDS)

print("PHASE 2: Retention measurement for " .. tostring(retention_time) .. " seconds")
print("Reading every " .. tostring(read_interval) .. " second(s)")
print("---")

local retention_reads = math.floor(retention_time / read_interval)
local start_time = os.time()

for read_num = 1, retention_reads do
    -- Wait for the interval
    delay(read_interval)
    
    -- Read resistance
    smu.source.output = smu.ON
    smu.source.level = read_voltage
    delay(read_delay)
    local current = smu.measure.read()
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    -- Calculate resistance and conductance
    local resistance = 0
    local conductance = 0
    if math.abs(current) > 1e-12 then
        resistance = read_voltage / current
        conductance = current / read_voltage
    end
    
    -- Actual elapsed time
    local elapsed = os.difftime(os.time(), start_time)
    
    -- Write to file
    file:write(string.format("Retention,0,%.6e,%.6e,%.6e,%.6e,%.6e\n",
        elapsed, read_voltage, current, resistance, conductance))
    
    -- TSP Lua 5.0 has no % operator; use math.mod()
    if math.mod(read_num, 10) == 0 or read_num == 1 then
        print(string.format("  t = %d s: I = %.3e A, R = %.3e Ω", 
            math.floor(elapsed), current, resistance))
    end
end

-- Close file
file:close()

-- Final cleanup
smu.source.level = 0
smu.source.output = smu.OFF

print("")
print("========================================================================")
print("MEASUREMENT COMPLETE!")
print("========================================================================")
print("Data saved to: " .. filename)
print("")
print("Summary:")
print("  - " .. tostring(num_pulses) .. " potentiation/depression pulses")
print("  - " .. tostring(retention_reads) .. " retention measurements")
print("  - Total measurement time: ~" .. tostring(retention_time) .. " seconds")
print("========================================================================")