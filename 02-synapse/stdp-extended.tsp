-- STDP (Spike-Timing-Dependent Plasticity) Measurement
-- Pre-Post and Post-Pre spike pairs with varying time intervals
-- Compatible with Keithley 2450 TSP
-- Min pulse width: 5ms

reset()

-- ===== SET NUMBER OF CYCLES HERE =====
local n_cycles = 1

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== STDP PARAMETERS =====
local pre_amplitude = 0.6 -- Pre-synaptic spike voltage
local post_amplitude = 0.6 -- Post-synaptic spike voltage
local pulse_width = 0.005 -- 5ms pulse width
local read_voltage = 0.1 -- Read voltage
local read_delay = 0.005 -- 5ms
local compliance = 1e-4

-- Time intervals between pre and post spikes (in seconds)
-- Positive: pre BEFORE post (potentiation)
-- Negative: post BEFORE pre (depression)
local delta_t_values = {
    0.100,   -- +100ms
    0.050,   -- +50ms
    0.020,   -- +20ms
    0.010,   -- +10ms
    0.005,   -- +5ms
    -0.005,  -- -5ms
    -0.010,  -- -10ms
    -0.020,  -- -20ms
    -0.050,  -- -50ms
    -0.100   -- -100ms
}

local num_repeats = 10 -- Number of spike pairs per delta_t

-- ===== GENERAL PARAMETERS =====
local base_filename = "/usb1/stdp_measurement_"

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.ilimit.level = compliance

print("========================================")
print("STDP Measurement")
print("Rear Terminals Selected")
print("========================================")
print("Number of cycles: " .. tostring(n_cycles))
print("Delta_t values: " .. tostring(table.getn(delta_t_values)))
print("Repeats per delta_t: " .. tostring(num_repeats))
print("========================================")
print("")

-- ===== HELPER FUNCTION: APPLY SPIKE PAIR =====
local function apply_spike_pair(delta_t)
    if delta_t >= 0 then
        -- Positive delta_t: Pre BEFORE Post (potentiation)
        -- Pre spike
        smu.source.output = smu.ON
        smu.source.level = pre_amplitude
        delay(pulse_width)
        smu.source.level = 0
        
        -- Wait delta_t
        delay(delta_t)
        
        -- Post spike
        smu.source.level = post_amplitude
        delay(pulse_width)
        smu.source.level = 0
        smu.source.output = smu.OFF
    else
        -- Negative delta_t: Post BEFORE Pre (depression)
        local abs_delta_t = math.abs(delta_t)
        
        -- Post spike
        smu.source.output = smu.ON
        smu.source.level = post_amplitude
        delay(pulse_width)
        smu.source.level = 0
        
        -- Wait |delta_t|
        delay(abs_delta_t)
        
        -- Pre spike
        smu.source.level = pre_amplitude
        delay(pulse_width)
        smu.source.level = 0
        smu.source.output = smu.OFF
    end
end

-- ===== MAIN STDP FUNCTION =====
local function perform_stdp(filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Delta_t_ms,Repeat_Number,Current_A,Resistance_Ohm,Spike_Order\n")
    
    for _, delta_t in ipairs(delta_t_values) do
        local delta_t_ms = delta_t * 1000
        local spike_order = "Pre-Post"
        if delta_t < 0 then
            spike_order = "Post-Pre"
        end
        
        print(string.format("  Delta_t: %.1f ms (%s)", delta_t_ms, spike_order))
        
        for repeat_num = 1, num_repeats do
            -- Apply spike pair
            apply_spike_pair(delta_t)
            
            -- Wait before reading
            delay(read_delay)
            
            -- Read resistance
            smu.source.output = smu.ON
            smu.source.level = read_voltage
            delay(read_delay)
            local i = smu.measure.read()
            local r = 0
            if math.abs(i) > 1e-12 then
                r = read_voltage / i
            end
            
            file:write(string.format("%.6e,%d,%.6e,%.6e,%s\n", delta_t_ms, repeat_num, i, r, spike_order))
            
            smu.source.level = 0
            smu.source.output = smu.OFF
            
            -- Inter-pair delay
            delay(0.05)
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
    
    print("=== STDP Measurement ===")
    print("File: " .. filename)
    print("---")
    
    local success = perform_stdp(filename)
    
    if success then
        print("Complete: STDP measurement")
        print("Data saved to: " .. filename)
    else
        print("FAILED: STDP measurement")
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