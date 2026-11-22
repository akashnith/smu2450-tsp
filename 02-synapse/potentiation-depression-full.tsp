-- Potentiation & Depression Measurement
-- 4 Test Cases: Fixed Amp, Incremental V, Incremental Pulse, Logarithmic V
-- Compatible with Keithley 2450 TSP
-- Min pulse width: 5ms
-- Use for more than 5 ms time operation , these are software and digited pulse creation works okay above 10ms

reset()

-- ===== SET NUMBER OF CYCLES HERE =====
local n_cycles = 10

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== TEST CONFIGURATIONS =====
local test_configs = {
    -- Case 1: Fixed amplitude, fixed pulse width
    {
        name = "fixed_amp_fixed_pulse",
        num_pulses = 50,
        amplitudes = {-1.5e-3,-2.5e-3,1.5e-3,2.0e-3,3e-3,4e-3},
        pulse_width = 0.005, -- 5ms
        read_delay = 0.010,
        compliance = 2e-4
    },
    
    -- Case 2: Incremental voltage, fixed pulse width
    {
        name = "incremental_V_fixed_pulse",
        num_pulses = 50,
        v_start =1e-4,
        v_end = 1.5e-3,
        v_step = 1e-4,
        pulse_width = 0.005, -- 5ms
        read_delay = 0.010,
        compliance = 2e-4
    },
    
    -- Case 3: Incremental pulse width, fixed voltage
    {
        name = "incremental_pulse_fixed_V",
        num_pulses = 50,
        amplitude = 1.5e-3,
        pw_start = 0.002, -- 2ms (minimum)
        pw_end = 0.050, -- 50ms
        pw_step = 0.00096, -- 50 steps
        read_delay = 0.010,
        compliance = 2e-4
    },
    
    -- Case 4: Logarithmic voltage increase, fixed pulse width
    {
        name = "logarithmic_V_fixed_pulse",
        num_pulses = 50,
        v_min = 1e-3,
        v_max = 2e-3,
        pulse_width = 0.005, -- 5ms
        read_delay = 0.010,
        compliance = 2e-4
    }
}

-- ===== GENERAL PARAMETERS =====
local read_voltage = 1e-4 --Read voltage between pulses
local base_filename = "/usb1/potentiation_depression_"

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON

print("========================================")
print("Potentiation & Depression Measurement")
print("Rear Terminals Selected")
print("========================================")
print("Number of cycles: " .. tostring(n_cycles))
print("========================================")
print("")

-- ===== HELPER: CASE 1 - FIXED AMP, FIXED PULSE =====
local function test_fixed_amp_fixed_pulse(config, filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Pulse_Number,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm\n")
    
    smu.source.ilimit.level = config.compliance
    
    for _, amp in ipairs(config.amplitudes) do
        print(string.format("  Testing amplitude: %.2f V", amp))
        
        for pulse = 1, config.num_pulses do
            -- Apply pulse
            smu.source.output = smu.ON
            smu.source.level = amp
            delay(config.pulse_width)
            smu.source.level = 0
            delay(config.read_delay)
            
            -- Read with small voltage
            smu.source.level = read_voltage
            delay(config.read_delay)
            local i = smu.measure.read()
            local r = 0
            if math.abs(i) > 1e-12 then
                r = read_voltage / i
            end
            
            file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, config.pulse_width, i, r))
            
            smu.source.level = 0
            smu.source.output = smu.OFF
            delay(0.01)
        end
    end
    
    file:close()
    return true
end

-- ===== HELPER: CASE 2 - INCREMENTAL V, FIXED PULSE =====
local function test_incremental_V_fixed_pulse(config, filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Pulse_Number,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm\n")
    
    smu.source.ilimit.level = config.compliance
    
    local amp = config.v_start
    for pulse = 1, config.num_pulses do
        -- Apply pulse
        smu.source.output = smu.ON
        smu.source.level = amp
        delay(config.pulse_width)
        smu.source.level = 0
        delay(config.read_delay)
        
        -- Read with small voltage
        smu.source.level = read_voltage
        delay(config.read_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = read_voltage / i
        end
        
        file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, config.pulse_width, i, r))
        
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.01)
        
        -- Increment voltage
        amp = amp + config.v_step
        if amp > config.v_end then
            amp = config.v_end
        end
    end
    
    file:close()
    return true
end

-- ===== HELPER: CASE 3 - INCREMENTAL PULSE, FIXED V =====
local function test_incremental_pulse_fixed_V(config, filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Pulse_Number,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm\n")
    
    smu.source.ilimit.level = config.compliance
    
    local pw = config.pw_start
    for pulse = 1, config.num_pulses do
        -- Apply pulse
        smu.source.output = smu.ON
        smu.source.level = config.amplitude
        delay(pw)
        smu.source.level = 0
        delay(config.read_delay)
        
        -- Read with small voltage
        smu.source.level = read_voltage
        delay(config.read_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = read_voltage / i
        end
        
        file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, config.amplitude, pw, i, r))
        
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.01)
        
        -- Increment pulse width
        pw = pw + config.pw_step
        if pw > config.pw_end then
            pw = config.pw_end
        end
    end
    
    file:close()
    return true
end

-- ===== HELPER: CASE 4 - LOGARITHMIC V, FIXED PULSE =====
local function test_logarithmic_V_fixed_pulse(config, filename)
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot open file " .. filename)
        return false
    end
    
    file:write("Pulse_Number,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm\n")
    
    smu.source.ilimit.level = config.compliance
    
    -- Generate logarithmic voltage steps
    local log_min = math.log10(config.v_min)
    local log_max = math.log10(config.v_max)
    local log_step = (log_max - log_min) / (config.num_pulses - 1)
    
    for pulse = 1, config.num_pulses do
        local amp = 10 ^ (log_min + (pulse - 1) * log_step)
        
        -- Apply pulse
        smu.source.output = smu.ON
        smu.source.level = amp
        delay(config.pulse_width)
        smu.source.level = 0
        delay(config.read_delay)
        
        -- Read with small voltage
        smu.source.level = read_voltage
        delay(config.read_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = read_voltage / i
        end
        
        file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, config.pulse_width, i, r))
        
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.01)
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
    
    for test_idx = 1, table.getn(test_configs) do
        local config = test_configs[test_idx]
        local filename = base_filename .. config.name .. "_run" .. tostring(cycle) .. ".csv"
        
        print("=== Test: " .. config.name .. " ===")
        print("File: " .. filename)
        
        local success = false
        if config.name == "fixed_amp_fixed_pulse" then
            success = test_fixed_amp_fixed_pulse(config, filename)
        elseif config.name == "incremental_V_fixed_pulse" then
            success = test_incremental_V_fixed_pulse(config, filename)
        elseif config.name == "incremental_pulse_fixed_V" then
            success = test_incremental_pulse_fixed_V(config, filename)
        elseif config.name == "logarithmic_V_fixed_pulse" then
            success = test_logarithmic_V_fixed_pulse(config, filename)
        end
        
        if success then
            print("Complete: " .. config.name)
        else
            print("FAILED: " .. config.name)
        end
        print("")
    end
    
    print("Cycle " .. tostring(cycle) .. " complete!")
    print("")
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

print("========================================")
print("All measurements complete!")
print("========================================")