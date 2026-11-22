
reset()

-- =====================================================================
-- GLOBAL CONFIGURATION
-- =====================================================================

-- DEVICE INFORMATION
local device_id = "sample_name_device_id"  -- Change for each device
local n_cycles = 1  -- Number of repetitions

-- FILE PATHS
local base_path = "/usb1/"
local log_file = base_path .. "measurement_log.txt"

-- TERMINAL SELECTION
smu.measure.terminals = smu.TERMINALS_REAR

-- SWEEP PARAMETERS
local voltage_levels = {0.001, 0.002, 0.005, 0.008}  -- 1mV, 2mV, 5mV, 8mV
local compliance_levels = {10e-6, 20e-6, 50e-6, 80e-6, 100e-6}  -- 10uA to 100uA
local step_size = 10e-6  -- 10µV step size
local sweep_delay = 0.02  -- 20ms delay for low current settling

-- READ PARAMETERS
local read_voltage = 0.0001  -- 100µV read voltage
local read_delay = 0.01  -- 10ms read delay

-- =====================================================================
-- HELPER FUNCTIONS
-- =====================================================================

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

local function read_resistance(read_v, read_d)
    smu.source.output = smu.ON
    smu.source.level = read_v
    delay(read_d)
    local current = smu.measure.read()
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    local resistance = 0
    if math.abs(current) > 1e-15 then
        resistance = read_v / current
    end
    
    return current, resistance
end

-- =====================================================================
-- LOW VOLTAGE DUAL SWEEP I-V
-- Organized by compliance groups
-- =====================================================================

local function low_voltage_iv_sweep()
    log_message("========== LOW VOLTAGE I-V CHARACTERIZATION ==========")
    log_message("Voltage levels: 1mV, 2mV, 5mV, 8mV")
    log_message("Compliance levels: 10uA, 20uA, 50uA, 80uA, 100uA")
    log_message("Step size: 10µV")
    
    -- Configure SMU for high precision
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.OFF
    smu.measure.range = 100e-6  -- 100µA range for best resolution
    
    -- Organize by COMPLIANCE GROUPS
    for cycle = 1, n_cycles do
        log_message("========================================")
        log_message("CYCLE " .. tostring(cycle) .. " of " .. tostring(n_cycles))
        log_message("========================================")
        
        for icc_idx, compliance in ipairs(compliance_levels) do
            local icc_ua = compliance * 1e6
            log_message("")
            log_message("--- COMPLIANCE GROUP: " .. string.format("%.0f", icc_ua) .. " µA ---")
            
            -- Test all voltage levels at this compliance
            for v_idx, v_max in ipairs(voltage_levels) do
                local v_mv = v_max * 1000
                local desc = string.format("%.0fmV_%.0fuA", v_mv, icc_ua)
                
                local filename = base_path .. "iv_" .. desc .. "_cycle" .. tostring(cycle) .. ".csv"
                local file = create_csv_file(filename, "Voltage_V,Current_A,Resistance_Ohm,Direction,Compliance,Voltage_mV,Current_uA")
                
                if file then
                
                log_message("  Measuring: " .. desc)
                
                -- Set compliance for this sweep
                smu.source.ilimit.level = compliance
                smu.source.output = smu.ON
                
                -- ===== FORWARD SWEEP: 0 → +Vmax =====
                local v = 0
                local step_count = 0
                while v <= v_max + 1e-9 do
                    smu.source.level = v
                    delay(sweep_delay)
                    local i = smu.measure.read()
                    local r = 0
                    if math.abs(i) > 1e-15 then
                        r = v / i
                    end
                    local comp = smu.source.compliance and "YES" or "NO"
                    local v_mv_actual = v * 1000
                    local i_ua = i * 1e6
                    
                    file:write(string.format("%.9e,%.9e,%.9e,FWD,%s,%.6f,%.6f\n", 
                        v, i, r, comp, v_mv_actual, i_ua))
                    
                    v = v + step_size
                    step_count = step_count + 1
                end
                
                -- ===== REVERSE SWEEP: +Vmax → 0 =====
                v = v_max
                while v >= -1e-9 do
                    smu.source.level = v
                    delay(sweep_delay)
                    local i = smu.measure.read()
                    local r = 0
                    if math.abs(i) > 1e-15 then
                        r = v / i
                    end
                    local comp = smu.source.compliance and "YES" or "NO"
                    local v_mv_actual = v * 1000
                    local i_ua = i * 1e6
                    
                    file:write(string.format("%.9e,%.9e,%.9e,REV,%s,%.6f,%.6f\n", 
                        v, i, r, comp, v_mv_actual, i_ua))
                    
                    v = v - step_size
                end
                
                -- ===== FORWARD SWEEP: 0 → -Vmax =====
                v = 0
                while v >= -v_max - 1e-9 do
                    smu.source.level = v
                    delay(sweep_delay)
                    local i = smu.measure.read()
                    local r = 0
                    if math.abs(i) > 1e-15 then
                        r = v / i
                    end
                    local comp = smu.source.compliance and "YES" or "NO"
                    local v_mv_actual = v * 1000
                    local i_ua = i * 1e6
                    
                    file:write(string.format("%.9e,%.9e,%.9e,FWD_NEG,%s,%.6f,%.6f\n", 
                        v, i, r, comp, v_mv_actual, i_ua))
                    
                    v = v - step_size
                end
                
                -- ===== REVERSE SWEEP: -Vmax → 0 =====
                v = -v_max
                while v <= 1e-9 do
                    smu.source.level = v
                    delay(sweep_delay)
                    local i = smu.measure.read()
                    local r = 0
                    if math.abs(i) > 1e-15 then
                        r = v / i
                    end
                    local comp = smu.source.compliance and "YES" or "NO"
                    local v_mv_actual = v * 1000
                    local i_ua = i * 1e6
                    
                    file:write(string.format("%.9e,%.9e,%.9e,REV_NEG,%s,%.6f,%.6f\n", 
                        v, i, r, comp, v_mv_actual, i_ua))
                    
                    v = v + step_size
                end
                
                -- Return to zero and turn off
                smu.source.level = 0
                smu.source.output = smu.OFF
                
                log_message("    Complete: " .. tostring(step_count * 4) .. " points measured")
                
                delay(0.5)  -- Brief pause between measurements
                end -- end if file
            end
            
            log_message("  Compliance group " .. string.format("%.0f", icc_ua) .. "µA complete")
        end
        
        log_message("")
        log_message("Cycle " .. tostring(cycle) .. " complete!")
        delay(1)
    end
    
    log_message("========== LOW VOLTAGE I-V COMPLETE ==========")
    return true
end

-- =====================================================================
-- POTENTIATION & DEPRESSION (Low Voltage)
-- =====================================================================

local function low_voltage_potentiation()
    log_message("========== LOW VOLTAGE POTENTIATION & DEPRESSION ==========")
    
    local pulse_amplitudes = {0.001, 0.002, 0.005, 0.008}  -- 1mV to 8mV
    local pulse_width = 0.01  -- 10ms pulses
    local num_pulses = 100
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.OFF
    smu.measure.range = 100e-6
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        for icc_idx, compliance in ipairs(compliance_levels) do
            local icc_ua = compliance * 1e6
            log_message("  Compliance: " .. string.format("%.0f", icc_ua) .. "µA")
            
            for _, amp in ipairs(pulse_amplitudes) do
                local amp_mv = amp * 1000
                local desc = string.format("pot_%.0fmV_%.0fuA", amp_mv, icc_ua)
                local filename = base_path .. desc .. "_cycle" .. tostring(cycle) .. ".csv"
                local file = create_csv_file(filename, "Pulse_Num,Amplitude_V,Pulse_Width_s,Current_A,Resistance_Ohm,Current_uA")
                
                if file then
                    for pulse = 1, num_pulses do
                        apply_pulse(amp, pulse_width, compliance)
                        delay(read_delay)
                        local i, r = read_resistance(read_voltage, read_delay)
                        local i_ua = i * 1e6
                        
                        file:write(string.format("%d,%.9e,%.6e,%.9e,%.9e,%.6f\n", 
                            pulse, amp, pulse_width, i, r, i_ua))
                        delay(0.02)
                    end
                    file:close()
                    log_message("    Complete: " .. desc)
                end
            end
        end
    end
    
    log_message("Phase 2 Complete")
    return true
end

-- =====================================================================
-- STDP (Low Voltage)
-- =====================================================================

local function low_voltage_stdp()
    log_message("========== LOW VOLTAGE STDP MEASUREMENT ==========")
    
    local spike_voltage = 0.005  -- 5mV spikes
    local pulse_width = 0.01
    local delta_t_values = {0.100, 0.050, 0.020, 0.010, 0.005, 0.002,
                            -0.002, -0.005, -0.010, -0.020, -0.050, -0.100}
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.OFF
    smu.measure.range = 100e-6
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        for icc_idx, compliance in ipairs(compliance_levels) do
            local icc_ua = compliance * 1e6
            smu.source.ilimit.level = compliance
            
            local filename = base_path .. "stdp_" .. string.format("%.0fuA", icc_ua) .. "_cycle" .. tostring(cycle) .. ".csv"
            local file = create_csv_file(filename, "Delta_t_ms,Repeat_Num,Current_A,Resistance_Ohm,Spike_Order,Current_uA")
            
            if file then
                for _, delta_t in ipairs(delta_t_values) do
                    local spike_order = delta_t >= 0 and "Pre-Post" or "Post-Pre"
                    
                    for repeat_num = 1, 10 do
                        if delta_t >= 0 then
                            smu.source.output = smu.ON
                            smu.source.level = spike_voltage
                            delay(pulse_width)
                            smu.source.level = 0
                            delay(delta_t)
                            smu.source.level = spike_voltage
                            delay(pulse_width)
                            smu.source.level = 0
                            smu.source.output = smu.OFF
                        else
                            smu.source.output = smu.ON
                            smu.source.level = spike_voltage
                            delay(pulse_width)
                            smu.source.level = 0
                            delay(math.abs(delta_t))
                            smu.source.level = spike_voltage
                            delay(pulse_width)
                            smu.source.level = 0
                            smu.source.output = smu.OFF
                        end
                        
                        delay(read_delay)
                        local i, r = read_resistance(read_voltage, read_delay)
                        local i_ua = i * 1e6
                        
                        file:write(string.format("%.6e,%d,%.9e,%.9e,%s,%.6f\n", 
                            delta_t * 1000, repeat_num, i, r, spike_order, i_ua))
                        delay(0.05)
                    end
                end
                file:close()
                log_message("  STDP complete for " .. string.format("%.0f", icc_ua) .. "µA")
            end
        end
    end
    
    log_message("Phase 3 Complete")
    return true
end

-- =====================================================================
-- PPF (Low Voltage)
-- =====================================================================

local function low_voltage_ppf()
    log_message("========== LOW VOLTAGE PPF MEASUREMENT ==========")
    
    local pulse_voltage = 0.005  -- 5mV
    local pulse_width = 0.01
    local intervals = {0.002, 0.005, 0.010, 0.020, 0.050, 0.100, 0.200, 0.500, 1.000, 2.000}
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.OFF
    smu.measure.range = 100e-6
    
    for cycle = 1, n_cycles do
        log_message("Cycle " .. tostring(cycle) .. "/" .. tostring(n_cycles))
        
        for icc_idx, compliance in ipairs(compliance_levels) do
            local icc_ua = compliance * 1e6
            smu.source.ilimit.level = compliance
            
            local filename = base_path .. "ppf_" .. string.format("%.0fuA", icc_ua) .. "_cycle" .. tostring(cycle) .. ".csv"
            local file = create_csv_file(filename, "Inter_Pulse_Interval_ms,Repeat_Num,Current_Before_A,Resistance_Before_Ohm,Current_After_A,Resistance_After_Ohm,PPF_Ratio")
            
            if file then
                for _, interval in ipairs(intervals) do
                    for repeat_num = 1, 10 do
                        local i_before, r_before = read_resistance(read_voltage, read_delay)
                        delay(read_delay)
                        
                        smu.source.output = smu.ON
                        smu.source.level = pulse_voltage
                        delay(pulse_width)
                        smu.source.level = 0
                        delay(interval)
                        smu.source.level = pulse_voltage
                        delay(pulse_width)
                        smu.source.level = 0
                        smu.source.output = smu.OFF
                        
                        delay(read_delay)
                        local i_after, r_after = read_resistance(read_voltage, read_delay)
                        
                        local ppf_ratio = 0
                        if math.abs(i_before) > 1e-15 then
                            ppf_ratio = i_after / i_before
                        end
                        
                        file:write(string.format("%.6e,%d,%.9e,%.9e,%.9e,%.9e,%.6e\n", 
                            interval * 1000, repeat_num, i_before, r_before, i_after, r_after, ppf_ratio))
                        delay(0.1)
                    end
                end
                file:close()
                log_message("  PPF complete for " .. string.format("%.0f", icc_ua) .. "µA")
            end
        end
    end
    
    log_message("Phase 4 Complete")
    return true
end

-- =====================================================================
-- MAIN EXECUTION
-- =====================================================================

print("========================================================================")
print("LOW VOLTAGE HIGH PRECISION HZO MEMRISTOR CHARACTERIZATION")
print("========================================================================")
print("Device ID: " .. device_id)
print("Voltage levels: 1mV, 2mV, 5mV, 8mV")
print("Compliance levels: 10µA, 20µA, 50µA, 80µA, 100µA")
print("Step size: 10µV")
print("Number of cycles: " .. tostring(n_cycles))
print("========================================================================")
print("")

-- Create device folder
os.execute("mkdir -p " .. base_path)

-- Initialize log
log_message("========== LOW VOLTAGE MEASUREMENT SESSION START ==========")
log_message("Device: " .. device_id)

-- Run all measurements
local success = true

success = success and low_voltage_iv_sweep()
delay(2)

success = success and low_voltage_potentiation()
delay(2)

success = success and low_voltage_stdp()
delay(2)

success = success and low_voltage_ppf()

-- Cleanup
smu.source.level = 0
smu.source.output = smu.OFF

if success then
    log_message("========== ALL MEASUREMENTS COMPLETED SUCCESSFULLY ==========")
    print("========================================================================")
    print("ALL LOW VOLTAGE MEASUREMENTS COMPLETE!")
    print("========================================================================")
else
    log_message("========== MEASUREMENTS COMPLETED WITH ERRORS ==========")
end

local total_files = (4 * 5 * n_cycles) + (4 * 5 * n_cycles) + (5 * n_cycles) + (5 * n_cycles)
print("Total files created: ~" .. tostring(total_files))
print("Data saved to: " .. base_path)
print("========================================================================")