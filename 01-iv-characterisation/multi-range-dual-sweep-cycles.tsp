-- Dual Sweep DC I-V: 0 -> +V -> 0 -> -V -> 0
-- Multiple voltage ranges with different compliance levels
-- Compatible with Keithley 2450 TSP
-- Multiple cycle support

reset()

-- ===== SET NUMBER OF CYCLES HERE =====
local n_cycles = 10 --E THIS NUMBER to set how many cycles to run

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== SWEEP CONFIGURATIONS =====
-- Organized by COMPLIANCE groups - all voltages at one compliance before moving to next
-- Each entry: {v_max, compliance, step_size, description}
local sweep_configs = {
    -- COMPLIANCE GROUP 1: 50µA - All voltages at 50µA first
    { v_max = 0.01, compliance = 50e-6,  step = 0.001, desc = "10mV_50uA" },
    { v_max = 0.05, compliance = 50e-6,  step = 0.005, desc = "50mV_50uA" },

    -- COMPLIANCE GROUP 2: 100µA - All voltages at 100µA
    { v_max = 0.01, compliance = 100e-6, step = 0.001, desc = "10mV_100uA" },
    { v_max = 0.05, compliance = 100e-6, step = 0.005, desc = "50mV_100uA" },
    { v_max = 0.1,  compliance = 100e-6, step = 0.01,  desc = "100mV_100uA" },
    { v_max = 0.5,  compliance = 100e-6, step = 0.05,  desc = "500mV_100uA" },
    { v_max = 1.0,  compliance = 100e-6, step = 0.05,  desc = "1V_100uA" },
    { v_max = 1.5,  compliance = 100e-6, step = 0.05,  desc = "1.5V_100uA" },

    -- COMPLIANCE GROUP 3: 500µA - All voltages at 500µA
    { v_max = 0.1,  compliance = 500e-6, step = 0.01,  desc = "100mV_500uA" },
    { v_max = 0.5,  compliance = 500e-6, step = 0.05,  desc = "500mV_500uA" },
    { v_max = 1.0,  compliance = 500e-6, step = 0.05,  desc = "1V_500uA" },
    { v_max = 1.5,  compliance = 500e-6, step = 0.05,  desc = "1.5V_500uA" },
    { v_max = 2,    compliance = 500e-6, step = 0.05,  desc = "02V_500uA" },
    { v_max = 3,    compliance = 500e-6, step = 0.05,  desc = "03V_500uA" }
    --
}

-- ===== GENERAL PARAMETERS =====
local sweep_delay = 0.01
local base_filename = "/usb1/dual_sweep_iv_sample_"

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON

print("========================================")
print("Multi-Cycle Multi-Compliance Dual Sweep DC I-V")
print("Rear Terminals Selected")
print("========================================")
print("Number of cycles: " .. tostring(n_cycles))
print("Total configurations per cycle: " .. tostring(table.getn(sweep_configs)))
print("========================================")
print("")

-- ===== HELPER FUNCTION TO PERFORM ONE SWEEP =====
local function perform_dual_sweep(v_max, compliance, sweep_step, desc, filename)
    local file = io.open(filename, "w")

    if not file then
        print("ERROR: Cannot open file " .. filename)
        print("Check USB drive and try again.")
        return false
    end

    -- Write header
    file:write("Voltage_V,Current_A,Resistance_Ohm,Direction,Compliance\n")

    -- Set compliance for this sweep
    smu.source.ilimit.level = compliance
    smu.source.output = smu.ON

    -- FORWARD SWEEP: 0 -> +Vmax
    local v = 0
    while v <= v_max + 1e-9 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = v / i
        end
        local comp = "NO"
        if smu.source.compliance then
            comp = "YES"
        end

        file:write(string.format("%.6e,%.6e,%.6e,FWD,%s\n", v, i, r, comp))
        v = v + sweep_step
    end

    -- REVERSE SWEEP: +Vmax -> 0
    v = v_max
    while v >= -1e-9 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = v / i
        end
        local comp = "NO"
        if smu.source.compliance then
            comp = "YES"
        end

        file:write(string.format("%.6e,%.6e,%.6e,REV,%s\n", v, i, r, comp))
        v = v - sweep_step
    end

    -- FORWARD SWEEP: 0 -> -Vmax
    v = 0
    while v >= -v_max - 1e-9 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = v / i
        end
        local comp = "NO"
        if smu.source.compliance then
            comp = "YES"
        end

        file:write(string.format("%.6e,%.6e,%.6e,FWD_NEG,%s\n", v, i, r, comp))
        v = v - sweep_step
    end

    -- REVERSE SWEEP: -Vmax -> 0
    v = -v_max
    while v <= 1e-9 do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        local r = 0
        if math.abs(i) > 1e-12 then
            r = v / i
        end
        local comp = "NO"
        if smu.source.compliance then
            comp = "YES"
        end

        file:write(string.format("%.6e,%.6e,%.6e,REV_NEG,%s\n", v, i, r, comp))
        v = v + sweep_step
    end

    -- Close file and reset to 0V
    file:close()
    smu.source.level = 0
    smu.source.output = smu.OFF

    return true
end

-- ===== MAIN CYCLE AND SWEEP LOOP =====
local total_configs = table.getn(sweep_configs)

for cycle = 1, n_cycles do
    print("########################################")
    print("### CYCLE " .. tostring(cycle) .. " of " .. tostring(n_cycles) .. " ###")
    print("########################################")
    print("")

    for config_idx = 1, total_configs do
        local config = sweep_configs[config_idx]
        local v_max = config.v_max
        local compliance = config.compliance
        local sweep_step = config.step
        local desc = config.desc

        -- Create filename with cycle number
        local filename = base_filename .. desc .. "_run" .. tostring(cycle) .. ".csv"

        print("=== Cycle " ..
            tostring(cycle) .. " - Configuration " .. tostring(config_idx) .. "/" .. tostring(total_configs) .. " ===")
        print(string.format("Vmax: %.3f V | Compliance: %.2e A | Step: %.4f V", v_max, compliance, sweep_step))
        print("File: " .. filename)
        print("---")

        -- Perform the sweep
        local success = perform_dual_sweep(v_max, compliance, sweep_step, desc, filename)

        if success then
            print("Complete: " .. desc)
            print("Data saved to: " .. filename)
        else
            print("FAILED: " .. desc)
        end

        print("")
        delay(0.5)
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
print("Total cycles run: " .. tostring(n_cycles))
print("Data saved to USB drive (/usb1/)")
print("File pattern: dual_sweep_iv_*_runN.csv")
print("========================================")
