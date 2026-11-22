-- COMPLETE HZO MEMRISTOR CHARACTERIZATION SUITE
-- All-in-one measurement script for neuromorphic device testing
-- Compatible with Keithley 2450 TSP

reset()

-- GLOBAL CONFIGURATION - MODIFY THESE PARAMETERS

-- DEVICE INFORMATION
local device_id = "TiPt_FE-HZO_W_Dev1"  -- Change for each device
local n_cycles = 3  -- Number of repetitions for each test

-- FILE PATHS
local base_path = "/usb1/" .. device_id .. "/"
local log_file = base_path .. "measurement_log.txt"

-- TERMINAL SELECTION
smu.measure.terminals = smu.TERMINALS_REAR

-- SAFETY LIMITS
local max_voltage = 3.0  -- Absolute maximum voltage
local max_current = 10e-4  -- Absolute maximum current (10mA)

-- HELPER FUNCTIONS

local function log_message(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    print(timestamp .. " - " .. message)
    
    local file = io.open(log_file, "a")
    if file then
        file:write(timestamp .. " - " .. message .. "\n")
        file:close()
    end
end

local function create_csv_file(filename, header)
    local file = io.open(filename, "w")
    if not file then
        log_message("ERROR: Cannot create file " .. filename)
        return nil
    end
    file:write(header .. "\n")
    return file
end

local function apply_pulse(voltage, pulse_width, compliance)
    smu.source.ilimit.level = compliance
    smu.source.output = smu.ON
    smu.source.level = voltage
    delay(pulse_width)
    smu.source.level = 0
    smu.source.output = smu.OFF
end

local function read_resistance(read_voltage, read_delay)
    smu.source.output = smu.ON
    smu.source.level = read_voltage
    delay(read_delay)
    local current = smu.measure.read()
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    local resistance = 0
    if math.abs(current) > 1e-12 then
        resistance = read_voltage / current
    end
    
    return current, resistance
end

-- PHASE 1: BASIC I-V CHARACTERIZATION

local function phase1_basic_iv()
    log_message("========== PHASE 1: BASIC I-V CHARACTERIZATION ==========")
    
    -- I-V Sweep Configurations
    local iv_configs = {
        {v_max = 1.0, compliance = 100e-6, step = 0.05, desc = "1V_100uA"},
        {v_max = 1.0, compliance = 500e-6, step = 0.05, desc = "2V_500uA"},
        {v_max = 1.5, compliance = 1e-4, step = 0.05, desc = "3V_1mA"},
        {v_max = 1.5, compliance = 5e-4, step = 0.1, desc = "4V_5mA"}
    }
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        for _, config in ipairs(iv_configs) do
            local filename = base_path .. "iv_" .. config.desc .. "_cycle" .. tostring(cycle) .. ".csv"
            local file = create_csv_file(filename, "Voltage_V,Current_A,Resistance_Ohm,Direction,Compliance")
            
            if not file then return false end
            
            log_message("Running I-V sweep: " .. config.desc)
            
            smu.source.ilimit.level = config.compliance
            smu.source.output = smu.ON
            
            -- Forward: 0 -> +V
            local v = 0
            while v <= config.v_max + 1e-9 do
                smu.source.level = v
                delay(0.01)
                local i = smu.measure.read()
                local r = math.abs(i) > 1e-12 and (v / i) or 0
                local comp = smu.source.compliance and "YES" or "NO"
                file:write(string.format("%.6e,%.6e,%.6e,FWD,%s\n", v, i, r, comp))
                v = v + config.step
            end
            
            -- Reverse: +V -> 0
            v = config.v_max
            while v >= -1e-9 do
                smu.source.level = v
                delay(0.01)
                local i = smu.measure.read()
                local r = math.abs(i) > 1e-12 and (v / i) or 0
                local comp = smu.source.compliance and "YES" or "NO"
                file:write(string.format("%.6e,%.6e,%.6e,REV,%s\n", v, i, r, comp))
                v = v - config.step
            end
            
            -- Forward: 0 -> -V
            v = 0
            while v >= -config.v_max - 1e-9 do
                smu.source.level = v
                delay(0.01)
                local i = smu.measure.read()
                local r = math.abs(i) > 1e-12 and (v / i) or 0
                local comp = smu.source.compliance and "YES" or "NO"
                file:write(string.format("%.6e,%.6e,%.6e,FWD_NEG,%s\n", v, i, r, comp))
                v = v - config.step
            end
            
            -- Reverse: -V -> 0
            v = -config.v_max
            while v <= 1e-9 do
                smu.source.level = v
                delay(0.01)
                local i = smu.measure.read()
                local r = math.abs(i) > 1e-12 and (v / i) or 0
                local comp = smu.source.compliance and "YES" or "NO"
                file:write(string.format("%.6e,%.6e,%.6e,REV_NEG,%s\n", v, i, r, comp))
                v = v + config.step
            end
            
            smu.source.level = 0
            smu.source.output = smu.OFF
            file:close()
            
            log_message("Completed: " .. config.desc)
            delay(0.5)
        end
    end
    
    log_message("Phase 1 Complete")
    return true
end

-- PHASE 2: POTENTIATION & DEPRESSION

local function phase2_potentiation_depression()
    log_message("========== PHASE 2: POTENTIATION & DEPRESSION ==========")
    
    local read_voltage = 0.1
    local read_delay = 0.002
    local compliance = 1e-3
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        -- TEST 1: Fixed amplitude, fixed pulse
        log_message("Test 1: Fixed amplitude, fixed pulse")
        local amplitudes = {0.5, 1.0, 1.5, 2.0}
        local filename = base_path .. "pot_fixed_amp_cycle" .. tostring(cycle) .. ".csv"
        local file = create_csv_file(filename, "Pulse_Num,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm")
        
        if file then
            for _, amp in ipairs(amplitudes) do
                for pulse = 1, 50 do
                    apply_pulse(amp, 0.005, compliance)
                    delay(read_delay)
                    local i, r = read_resistance(read_voltage, read_delay)
                    file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, 0.005, i, r))
                    delay(0.01)
                end
            end
            file:close()
        end
        
        -- TEST 2: Incremental voltage, fixed pulse
        log_message("Test 2: Incremental voltage")
        filename = base_path .. "pot_incr_voltage_cycle" .. tostring(cycle) .. ".csv"
        file = create_csv_file(filename, "Pulse_Num,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm")
        
        if file then
            local v_start = 0.2
            local v_step = 0.036
            local amp = v_start
            for pulse = 1, 50 do
                apply_pulse(amp, 0.005, compliance)
                delay(read_delay)
                local i, r = read_resistance(read_voltage, read_delay)
                file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, 0.005, i, r))
                amp = amp + v_step
                delay(0.01)
            end
            file:close()
        end
        
        -- TEST 3: Incremental pulse width, fixed voltage
        log_message("Test 3: Incremental pulse width")
        filename = base_path .. "pot_incr_pulse_cycle" .. tostring(cycle) .. ".csv"
        file = create_csv_file(filename, "Pulse_Num,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm")
        
        if file then
            local pw_start = 0.002
            local pw_step = 0.00096
            local pw = pw_start
            for pulse = 1, 50 do
                apply_pulse(1.5, pw, compliance)
                delay(read_delay)
                local i, r = read_resistance(read_voltage, read_delay)
                file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, 1.5, pw, i, r))
                pw = pw + pw_step
                delay(0.01)
            end
            file:close()
        end
        
        -- TEST 4: Logarithmic voltage, fixed pulse
        log_message("Test 4: Logarithmic voltage")
        filename = base_path .. "pot_log_voltage_cycle" .. tostring(cycle) .. ".csv"
        file = create_csv_file(filename, "Pulse_Num,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm")
        
        if file then
            local log_min = math.log10(0.1)
            local log_max = math.log10(2.0)
            local log_step = (log_max - log_min) / 49
            for pulse = 1, 50 do
                local amp = 10 ^ (log_min + (pulse - 1) * log_step)
                apply_pulse(amp, 0.005, compliance)
                delay(read_delay)
                local i, r = read_resistance(read_voltage, read_delay)
                file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e\n", pulse, amp, 0.005, i, r))
                delay(0.01)
            end
            file:close()
        end
    end
    
    log_message("Phase 2 Complete")
    return true
end

-- PHASE 3: STDP MEASUREMENT

local function phase3_stdp()
    log_message("========== PHASE 3: STDP MEASUREMENT ==========")
    
    local pre_amp = 1.0
    local post_amp = 1.0
    local pulse_width = 0.005
    local read_voltage = 0.1
    local read_delay = 0.002
    local compliance = 1e-3
    
    local delta_t_values = {0.100, 0.050, 0.020, 0.010, 0.005, 0.002,
                            -0.002, -0.005, -0.010, -0.020, -0.050, -0.100}
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        local filename = base_path .. "stdp_cycle" .. tostring(cycle) .. ".csv"
        local file = create_csv_file(filename, "Delta_t_ms,Repeat_Num,Current_A,Resistance_Ohm,Spike_Order")
        
        if not file then return false end
        
        for _, delta_t in ipairs(delta_t_values) do
            local spike_order = delta_t >= 0 and "Pre-Post" or "Post-Pre"
            
            for repeat_num = 1, 10 do
                -- Apply spike pair
                if delta_t >= 0 then
                    -- Pre before Post
                    smu.source.output = smu.ON
                    smu.source.level = pre_amp
                    delay(pulse_width)
                    smu.source.level = 0
                    delay(delta_t)
                    smu.source.level = post_amp
                    delay(pulse_width)
                    smu.source.level = 0
                    smu.source.output = smu.OFF
                else
                    -- Post before Pre
                    smu.source.output = smu.ON
                    smu.source.level = post_amp
                    delay(pulse_width)
                    smu.source.level = 0
                    delay(math.abs(delta_t))
                    smu.source.level = pre_amp
                    delay(pulse_width)
                    smu.source.level = 0
                    smu.source.output = smu.OFF
                end
                
                delay(read_delay)
                local i, r = read_resistance(read_voltage, read_delay)
                file:write(string.format("%.6e,%d,%.6e,%.6e,%s\n", delta_t * 1000, repeat_num, i, r, spike_order))
                delay(0.05)
            end
        end
        
        file:close()
        log_message("STDP cycle " .. tostring(cycle) .. " complete")
    end
    
    log_message("Phase 3 Complete")
    return true
end

-- PHASE 4: PPF MEASUREMENT

local function phase4_ppf()
    log_message("========== PHASE 4: PPF MEASUREMENT ==========")
    
    local pulse_amp = 1.5
    local pulse_width = 0.005
    local read_voltage = 0.1
    local read_delay = 0.002
    local compliance = 1e-3
    
    local intervals = {0.002, 0.005, 0.010, 0.020, 0.050, 0.100, 0.200, 0.500, 1.000, 2.000}
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        local filename = base_path .. "ppf_cycle" .. tostring(cycle) .. ".csv"
        local file = create_csv_file(filename, "Inter_Pulse_Interval_ms,Repeat_Num,Current_Before_A,Resistance_Before_Ohm,Current_After_A,Resistance_After_Ohm,PPF_Ratio")
        
        if not file then return false end
        
        for _, interval in ipairs(intervals) do
            for repeat_num = 1, 10 do
                -- Read before
                local i_before, r_before = read_resistance(read_voltage, read_delay)
                delay(read_delay)
                
                -- Apply paired pulse
                smu.source.output = smu.ON
                smu.source.level = pulse_amp
                delay(pulse_width)
                smu.source.level = 0
                delay(interval)
                smu.source.level = pulse_amp
                delay(pulse_width)
                smu.source.level = 0
                smu.source.output = smu.OFF
                
                delay(read_delay)
                
                -- Read after
                local i_after, r_after = read_resistance(read_voltage, read_delay)
                
                local ppf_ratio = 0
                if math.abs(i_before) > 1e-12 then
                    ppf_ratio = i_after / i_before
                end
                
                file:write(string.format("%.6e,%d,%.6e,%.6e,%.6e,%.6e,%.6e\n", 
                    interval * 1000, repeat_num, i_before, r_before, i_after, r_after, ppf_ratio))
                delay(0.1)
            end
        end
        
        file:close()
        log_message("PPF cycle " .. tostring(cycle) .. " complete")
    end
    
    log_message("Phase 4 Complete")
    return true
end

-- PHASE 5: ENDURANCE TEST

local function phase5_endurance()
    log_message("========== PHASE 5: ENDURANCE TEST ==========")
    
    local set_voltage = 2.0
    local reset_voltage = -2.0
    local pulse_width = 0.005
    local read_voltage = 0.1
    local read_delay = 0.002
    local compliance = 1e-3
    local max_cycles = 1000  -- Adjust as needed
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance
    
    local filename = base_path .. "endurance_test.csv"
    local file = create_csv_file(filename, "Cycle_Num,R_HRS_Ohm,R_LRS_Ohm,OnOff_Ratio,I_HRS_A,I_LRS_A")
    
    if not file then return false end
    
    log_message("Running " .. tostring(max_cycles) .. " endurance cycles")
    
    for cycle_num = 1, max_cycles do
        -- SET operation
        apply_pulse(set_voltage, pulse_width, compliance)
        delay(read_delay)
        local i_lrs, r_lrs = read_resistance(read_voltage, read_delay)
        
        -- RESET operation
        apply_pulse(reset_voltage, pulse_width, compliance)
        delay(read_delay)
        local i_hrs, r_hrs = read_resistance(read_voltage, read_delay)
        
        local onoff_ratio = 0
        if r_lrs > 0 and r_hrs > 0 then
            onoff_ratio = r_hrs / r_lrs
        end
        
        file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e,%.6e\n", 
            cycle_num, r_hrs, r_lrs, onoff_ratio, i_hrs, i_lrs))
        
        -- Log progress every 100 cycles
        if cycle_num - math.floor(cycle_num / 100) * 100 == 0 then
            log_message("Completed " .. tostring(cycle_num) .. " cycles")
        end
        
        delay(0.01)
    end
    
    file:close()
    log_message("Phase 5 Complete")
    return true
end

-- PHASE 6: RETENTION TEST

local function phase6_retention()
    log_message("========== PHASE 6: RETENTION TEST ==========")
    
    local set_voltage = 2.0
    local reset_voltage = -2.0
    local pulse_width = 0.005
    local read_voltage = 0.1
    local read_delay = 0.002
    local compliance = 1e-3
    
    local read_intervals = {1, 10, 100, 1000}  -- seconds
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance
    
    local filename = base_path .. "retention_test.csv"
    local file = create_csv_file(filename, "State,Time_s,Current_A,Resistance_Ohm")
    
    if not file then return false end
    
    -- Test HRS retention
    log_message("Testing HRS retention")
    apply_pulse(reset_voltage, pulse_width, compliance)
    delay(read_delay)
    
    for _, interval in ipairs(read_intervals) do
        delay(interval)
        local i, r = read_resistance(read_voltage, read_delay)
        file:write(string.format("HRS,%.6e,%.6e,%.6e\n", interval, i, r))
        log_message("HRS read at " .. tostring(interval) .. "s")
    end
    
    -- Test LRS retention
    log_message("Testing LRS retention")
    apply_pulse(set_voltage, pulse_width, compliance)
    delay(read_delay)
    
    for _, interval in ipairs(read_intervals) do
        delay(interval)
        local i, r = read_resistance(read_voltage, read_delay)
        file:write(string.format("LRS,%.6e,%.6e,%.6e\n", interval, i, r))
        log_message("LRS read at " .. tostring(interval) .. "s")
    end
    
    file:close()
    log_message("Phase 6 Complete")
    return true
end

-- MAIN EXECUTION

print("========================================================================")
print("HZO MEMRISTOR COMPLETE CHARACTERIZATION SUITE")
print("========================================================================")
print("Device ID: " .. device_id)
print("Number of cycles per test: " .. tostring(n_cycles))
print("Base path: " .. base_path)
print("========================================================================")
print("")

-- Create device folder
os.execute("mkdir -p " .. base_path)

-- Initialize log
log_message("========== MEASUREMENT SESSION START ==========")
log_message("Device: " .. device_id)

-- Configure SMU
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON

-- Run all phases
local success = true

success = success and phase1_basic_iv()
delay(2)

success = success and phase2_potentiation_depression()
delay(2)

success = success and phase3_stdp()
delay(2)

success = success and phase4_ppf()
delay(2)

success = success and phase5_endurance()
delay(2)

success = success and phase6_retention()

-- Cleanup
smu.source.level = 0
smu.source.output = smu.OFF

if success then
    log_message("========== ALL MEASUREMENTS COMPLETED SUCCESSFULLY ==========")
    print("========================================================================")
    print("ALL MEASUREMENTS COMPLETE!")
    print("========================================================================")
    print("Data saved to: " .. base_path)
else
    log_message("========== MEASUREMENTS COMPLETED WITH ERRORS ==========")
    print("========================================================================")
    print("MEASUREMENTS COMPLETED WITH SOME ERRORS")
    print("Check log file: " .. log_file)
    print("========================================================================")
end

print("Total files created:")
print("  - I-V sweeps: " .. tostring(4 * n_cycles))
print("  - Potentiation: " .. tostring(4 * n_cycles))
print("  - STDP: " .. tostring(n_cycles))
print("  - PPF: " .. tostring(n_cycles))
print("  - Endurance: 1")
print("  - Retention: 1")
print("  - Log file: 1")
print("========================================================================")