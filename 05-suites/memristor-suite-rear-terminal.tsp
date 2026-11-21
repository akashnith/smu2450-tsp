
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== GLOBAL PARAMETERS =====
local base_path = "/usb1/ALD15S"  -- USB path
local current_limit = 0.01   -- Global current compliance (A)
local timestamp = os.date("%Y%m%d_%H%M%S")

print("========================================")
print("NEUROMORPHIC MEASUREMENT SUITE")
print("Starting at: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("========================================\n")

-- Check USB availability
local test_file = io.open(base_path .. "test.txt", "w")
if test_file then
    test_file:close()
    os.remove(base_path .. "test.txt")
    print("USB drive detected: " .. base_path)
else
    print("WARNING: USB not detected, using internal memory")
    base_path = ""
end

-- ============================================================================
-- MEASUREMENT 1: DC I-V SWEEP
-- ============================================================================
print("\n[1/5] Starting DC I-V Sweep...")

local function run_dc_iv()
    local filename = base_path .. "dc_iv_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")
    
    if file then
        file:write("Voltage,Current\n")
    end
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 1.0
    
    smu.source.output = smu.ON
    
    print("Voltage(V), Current(A)")
    
    -- Forward sweep: 0 to 3V
    for v = 0, 2, 0.1 do
        smu.source.level = v
        delay(0.05)
        local i = smu.measure.read()
        local line = string.format("%.2f,%.6e", v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    -- Reverse sweep: 2V to 0
    for v = 2, 0, -0.1 do
        smu.source.level = v
        delay(0.05)
        local i = smu.measure.read()
        local line = string.format("%.2f,%.6e", v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end

    for v= -0.1, -2, -0.1 do
        smu.source.level = v
        delay(0.05)
        local i = smu.measure.read()
        local line = string.format("%.2f,%.6e", v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end

    for v= -2, 0, 0.1 do
        smu.source.level = v
        delay(0.05)
        local i = smu.measure.read()
        local line = string.format("%.2f,%.6e", v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    smu.source.level = 0
    smu.source.output = smu.OFF
    
    if file then
        file:close()
        print("DC I-V data saved to: " .. filename)
    end
end

run_dc_iv()

-- ============================================================================
-- MEASUREMENT 2: PULSE I-V
-- ============================================================================
print("\n[2/5] Starting Pulse I-V Measurement...")

local function run_pulse_iv()
    local filename = base_path .. "pulse_iv_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")
    
    if file then
        file:write("Pulse,Voltage,Current\n")
    end
    
    local pulse_width = 0.02
    local pulse_delay = 0.05
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 0.1
    
    smu.source.output = smu.ON
    
    print("Pulse#, Voltage(V), Current(A)")
    
    local pulse_num = 10
    for v = 0.1, 1.0, 0.10 do
        smu.source.level = v
        delay(pulse_width)
        local i = smu.measure.read()
        smu.source.level = 0
        
        local line = string.format("%d,%.2f,%.6e", pulse_num, v, i)
        print(line)
        if file then file:write(line .. "\n") end
        
        delay(pulse_delay)
        pulse_num = pulse_num + 1
    end
    
    smu.source.output = smu.OFF
    
    if file then
        file:close()
        print("Pulse I-V data saved to: " .. filename)
    end
end

run_pulse_iv()

-- ============================================================================
-- MEASUREMENT 3: LTP/LTD (Potentiation/Depression)
-- ============================================================================
print("\n[3/5] Starting LTP/LTD Measurement...")

local function run_ltp_ltd()
    local filename = base_path .. "ltp_ltd_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")
    
    if file then
        file:write("Cycle,Type,Current,Conductance\n")
    end

    local set_voltage = -0.8
    local reset_voltage = 1.5
    local pulse_width = 0.010
    local read_voltage = 0.01
    local num_cycles = 32
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 0.1
    
    smu.source.output = smu.ON
    
    print("Cycle, Type, Current(A), Conductance(S)")
    
    for cycle = 1, num_cycles do
        -- SET pulse (Potentiation)
        smu.source.level = set_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(0.01)
        
        -- Read state
        smu.source.level = read_voltage
        delay(0.001)
        local i_set = smu.measure.read()
        local g_set = i_set / read_voltage
        smu.source.level = 0
        
        local line = string.format("%d,SET,%.6e,%.6e", cycle, i_set, g_set)
        print(line)
        if file then file:write(line .. "\n") end
        delay(0.05)
        
        -- RESET pulse (Depression)
        smu.source.level = reset_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(0.01)
        
        -- Read state
        smu.source.level = read_voltage
        delay(0.001)
        local i_reset = smu.measure.read()
        local g_reset = i_reset / read_voltage
        smu.source.level = 0
        
        line = string.format("%d,RESET,%.6e,%.6e", cycle, i_reset, g_reset)
        print(line)
        if file then file:write(line .. "\n") end
        delay(0.05)
    end
    
    smu.source.output = smu.OFF
    
    if file then
        file:close()
        print("LTP/LTD data saved to: " .. filename)
    end
end

run_ltp_ltd()

-- ============================================================================
-- MEASUREMENT 4: STDP (Spike-Timing-Dependent Plasticity)
-- ============================================================================
print("\n[4/5] Starting STDP Measurement...")

local function run_stdp()
    local filename = base_path .. "stdp_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")
    
    if file then
        file:write("DeltaT,Conductance_Change\n")
    end
    
    local pre_voltage = -0.8
    local post_voltage = -1.2
    local pulse_width = 0.010
    local read_voltage = 0.1
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 0.1
    
    smu.source.output = smu.ON
    
    print("DeltaT(ms), Conductance_Change(S)")
    
    -- Test different timing intervals
    local delta_t_values = {-100, -50, -20, -10, -5, -2, -1, 0, 1, 2, 5, 10, 50, 100}  -- ms
    
    for _, dt in ipairs(delta_t_values) do
        -- Measure initial conductance
        smu.source.level = read_voltage
        delay(0.001)
        local i_initial = smu.measure.read()
        local g_initial = i_initial / read_voltage
        smu.source.level = 0
        delay(0.01)
        
        if dt < 0 then
            -- Post before Pre
            smu.source.level = post_voltage
            delay(pulse_width)
            smu.source.level = 0
            delay(math.abs(dt) / 1000)  -- Convert ms to seconds
            smu.source.level = pre_voltage
            delay(pulse_width)
            smu.source.level = 0
        else
            -- Pre before Post
            smu.source.level = pre_voltage
            delay(pulse_width)
            smu.source.level = 0
            delay(dt / 1000)
            smu.source.level = post_voltage
            delay(pulse_width)
            smu.source.level = 0
        end
        
        delay(0.02)
        
        -- Measure final conductance
        smu.source.level = read_voltage
        delay(0.001)
        local i_final = smu.measure.read()
        local g_final = i_final / read_voltage
        smu.source.level = 0
        
        local g_change = g_final - g_initial
        
        local line = string.format("%d,%.6e", dt, g_change)
        print(line)
        if file then file:write(line .. "\n") end
        
        delay(0.1)
    end
    
    smu.source.output = smu.OFF
    
    if file then
        file:close()
        print("STDP data saved to: " .. filename)
    end
end

run_stdp()

-- ============================================================================
-- MEASUREMENT 5: RETENTION TEST
-- ============================================================================
print("\n[5/5] Starting Retention Test...")

local function run_retention()
    local filename = base_path .. "retention_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")
    
    if file then
        file:write("Time,State,Current,Conductance\n")
    end
    
    local set_voltage = -0.8
    local reset_voltage = 1.5
    local pulse_width = 0.010
    local read_voltage = 0.1
    local read_intervals = {0, 1, 5, 10, 30, 60, 120, 300}  -- seconds
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 0.01
    
    smu.source.output = smu.ON
    
    print("Time(s), State, Current(A), Conductance(S)")
    
    -- Program to high conductance state
    smu.source.level = set_voltage
    delay(pulse_width)
    smu.source.level = 0
    delay(0.05)
    
    local start_time = os.clock()
    
    for _, interval in ipairs(read_intervals) do
        -- Wait for the interval
        local elapsed = os.clock() - start_time
        if interval > elapsed then
            delay(interval - elapsed)
        end
        
        -- Read conductance
        smu.source.level = read_voltage
        delay(0.001)
        local i_read = smu.measure.read()
        local g_read = i_read / read_voltage
        smu.source.level = 0
        
        local actual_time = os.clock() - start_time
        local line = string.format("%.2f,HRS,%.6e,%.6e", actual_time, i_read, g_read)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    smu.source.output = smu.OFF
    
    if file then
        file:close()
        print("Retention data saved to: " .. filename)
    end
end

run_retention()

local function run_multilevel_retention()

    local filename = base_path .. "multilevel_retention_" .. timestamp .. ".csv"
    local file = io.open(filename, "w")

    if file then
        file:write("Time_s,State,Program_V,Current_A,Conductance_S\n")
    end

    -- ===============================
    -- PARAMETERS
    -- ===============================
    local num_states     = 16
    local v_start        = 0.8
    local v_end          = 1.5
    local pulse_width    = 0.010      -- 10 ms
    local reset_voltage  = -1.5
    local reset_width    = 0.010
    local read_voltage   = 0.01

    local read_intervals = {0, 1, 5, 10, 30, 60, 120, 300}

    local dv = (v_end - v_start) / (num_states - 1)

    -- ===============================
    -- SMU CONFIGURATION
    -- ===============================
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.source.autorange = smu.ON
    smu.source.ilimit.level = current_limit
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.measure.nplc = 0.01
    smu.source.output = smu.ON

    print("Time(s), State, Program_V, Current(A), Conductance(S)")

    -- ===============================
    -- LOOP OVER STATES
    -- ===============================
    for state = 1, num_states do

        local program_voltage = v_start + (state - 1) * dv

        print(string.format(
            "Programming State %d/%d at %.3f V",
            state, num_states, program_voltage
        ))

        -- -------------------------------
        -- RESET (baseline)
        -- -------------------------------
        smu.source.level = reset_voltage
        delay(reset_width)
        smu.source.level = 0
        delay(0.1)

        -- -------------------------------
        -- PROGRAM STATE
        -- -------------------------------
        smu.source.level = program_voltage
        delay(pulse_width)
        smu.source.level = 0
        delay(0.05)

        -- -------------------------------
        -- RETENTION MEASUREMENT
        -- -------------------------------
        local start_time = os.clock()

        for _, interval in ipairs(read_intervals) do

            local elapsed = os.clock() - start_time
            if interval > elapsed then
                delay(interval - elapsed)
            end

            smu.source.level = read_voltage
            delay(0.001)
            local i_read = smu.measure.read()
            local g_read = i_read / read_voltage
            smu.source.level = 0

            local t = os.clock() - start_time

            local line = string.format(
                "%.2f,%d,%.3f,%.6e,%.6e",
                t, state, program_voltage, i_read, g_read
            )

            print(line)
            if file then file:write(line .. "\n") end
        end

        delay(0.5)
    end

    -- ===============================
    -- CLEANUP
    -- ===============================
    smu.source.output = smu.OFF

    if file then
        file:close()
        print("Multilevel retention data saved to: " .. filename)
    end
end

run_multilevel_retention()

-- ============================================================================
-- MEASUREMENT SUITE COMPLETE
-- ============================================================================
print("\n========================================")
print("ALL MEASUREMENTS COMPLETE!")
print("Finished at: " .. os.date("%Y-%m-%d %H:%M:%S"))
print("========================================")
print("\nFiles saved with timestamp: " .. timestamp)
print("Data location: " .. base_path)