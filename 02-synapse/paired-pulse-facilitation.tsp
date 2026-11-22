-- PPF (Paired-Pulse Facilitation) Measurement
-- Two identical pulses with varying inter-pulse intervals
-- Compatible with Keithley 2450 TSP
-- Min pulse width: 5 ms

reset()

-- ===== SET NUMBER OF CYCLES HERE =====
local n_cycles = 3

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== PPF PARAMETERS =====
local pulse_amplitude = 1.5 -- Pulse voltage
local pulse_width = 0.005 -- 5ms pulse width
local read_voltage = 0.1 -- Read voltage
local read_delay = 0.005 -- 5ms
local compliance = 1e-3

-- Inter-pulse intervals (time between first and second pulse)
local inter_pulse_intervals = {
    0.005,   -- 5ms
    0.010,   -- 10ms
    0.020,   -- 20ms
    0.050,   -- 50ms
    0.100,   -- 100ms
    0.200,   -- 200ms
    0.500,   -- 500ms
    1.000,   -- 1s
    2.000    -- 2s
}

local num_repeats = 10 -- Number of pulse pairs per interval

-- ===== GENERAL PARAMETERS =====
local base_filename = "/usb1/ppf_measurement_"

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.ilimit.level = compliance

print("========================================")
print("PPF (Paired-Pulse Facilitation) Measurement")
print("Rear Terminals Selected")
print("========================================")
print("Number of cycles: " .. tostring(n_cycles))
print("Inter-pulse intervals: " .. tostring(table.getn(inter_pulse_intervals)))
print("Repeats per interval: " .. tostring(num_repeats))
print("========================================")
print("")

-- ===== HELPER FUNCTION: APPLY PAIRED PULSE =====
local function apply_paired_pulse(interval)
    -- First pulse
    smu.source.output = smu.ON
    smu.source.level = pulse_amplitude
    delay(pulse_width)
    smu.source.level = 0
    
    -- Inter-pulse interval
    delay(interval)
    
    -- Second pulse
    smu.source.level = pulse_amplitude
    delay(pulse_width)
    smu.source.level = 0
    smu.source.output = smu.OFF
end

-- ===== MAIN PPF FUNCTION =====
local function perform_ppf(filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Inter_Pulse_Interval_ms,Repeat_Number,Current_Before_A,Resistance_Before_Ohm,Current_After_A,Resistance_After_Ohm,PPF_Ratio\n")
    
    for _, interval in ipairs(inter_pulse_intervals) do
        local interval_ms = interval * 1000
        
        print(string.format("  Inter-pulse interval: %.1f ms", interval_ms))
        
        for repeat_num = 1, num_repeats do
            -- Measure resistance BEFORE paired pulse
            smu.source.output = smu.ON
            smu.source.level = read_voltage
            delay(read_delay)
            local i_before = smu.measure.read()
            local r_before = 0
            if math.abs(i_before) > 1e-12 then
                r_before = read_voltage / i_before
            end
            smu.source.level = 0
            smu.source.output = smu.OFF
            delay(read_delay)
            
            -- Apply paired pulse
            apply_paired_pulse(interval)
            
            -- Wait before reading after
            delay(read_delay)
            
            -- Measure resistance AFTER paired pulse
            smu.source.output = smu.ON
            smu.source.level = read_voltage
            delay(read_delay)
            local i_after = smu.measure.read()
            local r_after = 0
            if math.abs(i_after) > 1e-12 then
                r_after = read_voltage / i_after
            end
            smu.source.level = 0
            smu.source.output = smu.OFF
            
            -- Calculate PPF ratio (conductance ratio)
            local ppf_ratio = 0
            if math.abs(i_before) > 1e-12 then
                ppf_ratio = i_after / i_before
            end
            
            file:write(string.format("%.6e,%d,%.6e,%.6e,%.6e,%.6e,%.6e\n", 
                interval_ms, repeat_num, i_before, r_before, i_after, r_after, ppf_ratio))
            
            -- Inter-trial delay
            delay(0.1)
        end
    end
    
    file:close()
    return true
end

-- ===== MAIN LOOP =====
for cycle = 1, n_cycles do
    print("########################################")
    print("### CYCLE " .. tostring(cycle) .. " of " .. tostring(n_cycles) .. " ###")
    print("########################################")
    print("")
    
    local filename = base_filename .. "run" .. tostring(cycle) .. ".csv"
    
    print("=== PPF Measurement ===")
    print("File: " .. filename)
    print("---")
    
    local success = perform_ppf(filename)
    
    if success then
        print("Complete: PPF measurement")
        print("Data saved to: " .. filename)
    else
        print("FAILED: PPF measurement")
    end
    
    print("")
    print("Cycle " .. tostring(cycle) .. " complete!")
    print("")
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

print("========================================")
print("All measurements complete!")
print("========================================")
print("Data saved to USB drive (/usb1/)")
print("========================================")