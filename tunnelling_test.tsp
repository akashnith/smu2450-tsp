-- ========================================================================
-- TUNNELING vs RESISTIVE SWITCHING CHARACTERIZATION
-- For ultra-thin films (5nm) - Comprehensive conduction mechanism analysis
-- Compatible with Keithley 2450 TSP
-- ========================================================================

reset()

-- =====================================================================
-- CONFIGURATION
-- =====================================================================

local device_id = "5nm_Sample1"
local base_path = "/usb1/" 

-- TERMINAL SELECTION
smu.measure.terminals = smu.TERMINALS_REAR

-- TEST PARAMETERS
local max_voltage = 0.5  -- Maximum voltage for safety
local compliance_current = 10e-5  -- 10mA compliance (high for tunneling check)

-- =====================================================================
-- TEST 1: ULTRA-SLOW I-V SWEEP (Check for hysteresis/gap)
-- =====================================================================

local function test1_slow_iv_sweep()
    print("\n========================================")
    print("TEST 1: ULTRA-SLOW I-V SWEEP")
    print("Purpose: Check for resistive switching gap")
    print("========================================")
    
    local filename = base_path .. "test1_slow_iv_sweep.csv"
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot create file")
        return false
    end
    
    file:write("Voltage_V,Current_A,Resistance_Ohm,Direction\n")
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance_current
    
    local v_step = 0.01  -- 10mV steps
    local sweep_delay = 0.1  -- 100ms delay for equilibration
    
    print("Sweeping: 0 -> +V -> 0 -> -V -> 0")
    print("Step: 10mV, Delay: 100ms")
    
    smu.source.output = smu.ON
    
    -- Forward sweep: 0 -> +V
    local v = 0
    while v <= max_voltage + 1e-6 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = math.abs(i) > 1e-12 and (v / i) or 0
        file:write(string.format("%.6e,%.6e,%.6e,FWD\n", v, i, r))
        v = v + v_step
    end
    
    -- Reverse sweep: +V -> 0
    v = max_voltage
    while v >= -1e-6 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = math.abs(i) > 1e-12 and (v / i) or 0
        file:write(string.format("%.6e,%.6e,%.6e,REV\n", v, i, r))
        v = v - v_step
    end
    
    -- Forward negative: 0 -> -V
    v = 0
    while v >= -max_voltage - 1e-6 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = math.abs(i) > 1e-12 and (v / i) or 0
        file:write(string.format("%.6e,%.6e,%.6e,FWD_NEG\n", v, i, r))
        v = v - v_step
    end
    
    -- Reverse negative: -V -> 0
    v = -max_voltage
    while v <= 1e-6 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = math.abs(i) > 1e-12 and (v / i) or 0
        file:write(string.format("%.6e,%.6e,%.6e,REV_NEG\n", v, i, r))
        v = v + v_step
    end
    
    smu.source.level = 0
    smu.source.output = smu.OFF
    file:close()
    
    print("Test 1 complete: " .. filename)
    return true
end

-- =====================================================================
-- TEST 2: MULTI-CYCLE I-V (Check for memory/switching)
-- =====================================================================

local function test2_multicycle_iv()
    print("\n========================================")
    print("TEST 2: MULTI-CYCLE I-V SWEEP")
    print("Purpose: Check for cycle-dependent behavior")
    print("========================================")
    
    local filename = base_path .. "test2_multicycle_iv.csv"
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot create file")
        return false
    end
    
    file:write("Cycle,Voltage_V,Current_A,Resistance_Ohm,Direction\n")
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance_current
    
    local num_cycles = 5
    local v_step = 0.05  -- 50mV steps for faster sweep
    local sweep_delay = 0.02
    
    print("Running " .. tostring(num_cycles) .. " cycles")
    
    for cycle = 1, num_cycles do
        print("  Cycle " .. tostring(cycle) .. "/" .. tostring(num_cycles))
        
        smu.source.output = smu.ON
        
        -- Quick bipolar sweep
        local v = 0
        while v <= max_voltage + 1e-6 do
            smu.source.level = v
            delay(sweep_delay)
            local i = smu.measure.read()
            local r = math.abs(i) > 1e-12 and (v / i) or 0
            file:write(string.format("%d,%.6e,%.6e,%.6e,FWD\n", cycle, v, i, r))
            v = v + v_step
        end
        
        v = max_voltage
        while v >= -max_voltage - 1e-6 do
            smu.source.level = v
            delay(sweep_delay)
            local i = smu.measure.read()
            local r = math.abs(i) > 1e-12 and (v / i) or 0
            file:write(string.format("%d,%.6e,%.6e,%.6e,REV\n", cycle, v, i, r))
            v = v - v_step
        end
        
        v = -max_voltage
        while v <= 1e-6 do
            smu.source.level = v
            delay(sweep_delay)
            local i = smu.measure.read()
            local r = math.abs(i) > 1e-12 and (v / i) or 0
            file:write(string.format("%d,%.6e,%.6e,%.6e,REV_NEG\n", cycle, v, i, r))
            v = v + v_step
        end
        
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.5)
    end
    
    file:close()
    print("Test 2 complete: " .. filename)
    return true
end

-- =====================================================================
-- TEST 3: VOLTAGE-DEPENDENT RESISTANCE (Fowler-Nordheim check)
-- =====================================================================

local function test3_voltage_dependent_resistance()
    print("\n========================================")
    print("TEST 3: VOLTAGE-DEPENDENT RESISTANCE")
    print("Purpose: Check for tunneling characteristics")
    print("========================================")
    
    local filename = base_path .. "test3_voltage_dependent_R.csv"
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot create file")
        return false
    end
    
    file:write("Voltage_V,Current_A,Resistance_Ohm,Conductance_S,Log_I,Log_V,FN_Y,FN_X\n")
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance_current
    
    -- Sweep from low to high voltage with fine steps
    local voltages = {}
    local v = 0.1
    while v <= max_voltage do
        table.insert(voltages, v)
        v = v + 0.1
    end
    
    print("Testing " .. tostring(table.getn(voltages)) .. " voltage points")
    
    smu.source.output = smu.ON
    
    for _, volt in ipairs(voltages) do
        smu.source.level = volt
        delay(0.05)
        local current = smu.measure.read()
        
        local resistance = 0
        local conductance = 0
        if math.abs(current) > 1e-12 then
            resistance = volt / current
            conductance = current / volt
        end
        
        -- Calculate Fowler-Nordheim coordinates: ln(I/V²) vs 1/V
        local log_i = math.log(math.abs(current))
        local log_v = math.log(volt)
        local fn_y = math.log(math.abs(current) / (volt * volt))  -- ln(I/V²)
        local fn_x = 1.0 / volt  -- 1/V
        
        file:write(string.format("%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e\n",
            volt, current, resistance, conductance, log_i, log_v, fn_y, fn_x))
    end
    
    smu.source.level = 0
    smu.source.output = smu.OFF
    file:close()
    
    print("Test 3 complete: " .. filename)
    return true
end

-- =====================================================================
-- TEST 4: PULSE RESPONSE (Memory effect check)
-- =====================================================================

local function test4_pulse_response()
    print("\n========================================")
    print("TEST 4: PULSE RESPONSE TEST")
    print("Purpose: Check for state retention")
    print("========================================")
    
    local filename = base_path .. "test4_pulse_response.csv"
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot create file")
        return false
    end
    
    file:write("Test_Num,Pulse_Voltage_V,Pre_Pulse_I_A,Post_Pulse_I_A,Retention_10s_I_A,Change_Percent\n")
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance_current
    
    local read_voltage = 0.1  -- 100mV read voltage
    local pulse_voltages = {0.01, 0.05, 0.1, 0.5, 0.2, -0.01, -0.05, -0.5, -0.25, -1.0}
    local pulse_width = 0.01  -- 10ms pulse
    
    print("Testing " .. tostring(table.getn(pulse_voltages)) .. " pulse voltages")
    
    for idx, pulse_v in ipairs(pulse_voltages) do
        -- Read before pulse
        smu.source.output = smu.ON
        smu.source.level = read_voltage
        delay(0.01)
        local i_before = smu.measure.read()
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.1)
        
        -- Apply pulse
        smu.source.output = smu.ON
        smu.source.level = pulse_v
        delay(pulse_width)
        smu.source.level = 0
        smu.source.output = smu.OFF
        delay(0.01)
        
        -- Read immediately after pulse
        smu.source.output = smu.ON
        smu.source.level = read_voltage
        delay(0.01)
        local i_after = smu.measure.read()
        smu.source.level = 0
        smu.source.output = smu.OFF
        
        -- Wait 10 seconds
        delay(10)
        
        -- Read after retention
        smu.source.output = smu.ON
        smu.source.level = read_voltage
        delay(0.01)
        local i_retention = smu.measure.read()
        smu.source.level = 0
        smu.source.output = smu.OFF
        
        -- Calculate change
        local change_percent = 0
        if math.abs(i_before) > 1e-12 then
            change_percent = ((i_after - i_before) / i_before) * 100
        end
        
        file:write(string.format("%d,%.6e,%.6e,%.6e,%.6e,%.2f\n",
            idx, pulse_v, i_before, i_after, i_retention, change_percent))
        
        print(string.format("  Pulse %.1fV: ΔI = %.1f%%", pulse_v, change_percent))
        
        delay(1)
    end
    
    file:close()
    print("Test 4 complete: " .. filename)
    return true
end

-- =====================================================================
-- TEST 5: LOW VOLTAGE LINEARITY (Ohmic check)
-- =====================================================================

local function test5_low_voltage_linearity()
    print("\n========================================")
    print("TEST 5: LOW VOLTAGE LINEARITY")
    print("Purpose: Check for ohmic vs non-ohmic behavior")
    print("========================================")
    
    local filename = base_path .. "test5_low_voltage_linearity.csv"
    local file = io.open(filename, "w")
    if not file then
        print("ERROR: Cannot create file")
        return false
    end
    
    file:write("Voltage_V,Current_A,Resistance_Ohm\n")
    
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.measure.autorange = smu.ON
    smu.source.ilimit.level = compliance_current
    
    -- Very fine sweep at low voltage
    local v_max = 0.5  -- 500mV maximum
    local v_step = 0.001  -- 1mV steps
    local sweep_delay = 0.05
    
    print("Sweeping 0 to 500mV with 1mV steps")
    
    smu.source.output = smu.ON
    
    -- Forward sweep
    local v = 0
    while v <= v_max + 1e-6 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = math.abs(i) > 1e-12 and (v / i) or 0
        file:write(string.format("%.6e,%.6e,%.6e\n", v, i, r))
        v = v + v_step
    end
    
    smu.source.level = 0
    smu.source.output = smu.OFF
    file:close()
    
    print("Test 5 complete: " .. filename)
    return true
end

-- =====================================================================
-- MAIN EXECUTION
-- =====================================================================

print("========================================================================")
print("TUNNELING vs RESISTIVE SWITCHING CHARACTERIZATION")
print("For ultra-thin films (5nm)")
print("========================================================================")
print("Device: " .. device_id)
print("Max Voltage: " .. tostring(max_voltage) .. " V")
print("Compliance: " .. tostring(compliance_current * 1e3) .. " mA")
print("========================================================================")

-- Create output directory
os.execute("mkdir -p " .. base_path)

local success = true

-- Run all tests
success = success and test1_slow_iv_sweep()
delay(2)

success = success and test2_multicycle_iv()
delay(2)

success = success and test3_voltage_dependent_resistance()
delay(2)

success = success and test4_pulse_response()
delay(2)

success = success and test5_low_voltage_linearity()

-- Cleanup
smu.source.level = 0
smu.source.output = smu.OFF

print("\n========================================================================")
if success then
    print("ALL TESTS COMPLETED SUCCESSFULLY")
else
    print("TESTS COMPLETED WITH SOME ERRORS")
end
print("========================================================================")
print("\nData saved to: " .. base_path)
print("\nGenerated files:")
print("  1. test1_slow_iv_sweep.csv - Check for switching gap")
print("  2. test2_multicycle_iv.csv - Check for memory/history")
print("  3. test3_voltage_dependent_R.csv - Fowler-Nordheim analysis")
print("  4. test4_pulse_response.csv - State retention check")
print("  5. test5_low_voltage_linearity.csv - Ohmic behavior check")
print("\n========================================================================")
print("ANALYSIS GUIDE:")
print("========================================================================")
print("TUNNELING indicators:")
print("  - No hysteresis gap (Test 1)")
print("  - Linear I-V at low voltage (Test 5)")
print("  - No cycle-to-cycle variation (Test 2)")
print("  - No memory/retention (Test 4: change% near 0)")
print("  - FN plot: linear ln(I/V²) vs 1/V (Test 3)")
print("")
print("RESISTIVE SWITCHING indicators:")
print("  - Clear hysteresis gap (Test 1)")
print("  - Cycle-dependent behavior (Test 2)")
print("  - Memory effect (Test 4: large change%)")
print("  - Non-linear at low voltage (Test 5)")
print("  - State retention >10s (Test 4)")
print("========================================================================")