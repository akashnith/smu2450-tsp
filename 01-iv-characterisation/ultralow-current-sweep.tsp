-- Dual Sweep DC I-V: 0 -> +V -> 0 -> -V -> 0
reset()

-- ===== SELECT REAR TERMINALS =====
smu.measure.terminals = smu.TERMINALS_REAR

-- ===== SWEEP PARAMETERS =====
local v_start = 0.01           -- Starting voltage (V)
local v_end = 0.51             -- Ending voltage (V)
local v_step = 0.1             -- Voltage step (V)
local sweep_step = 0.1           -- Step size during sweep (V)
local sweep_delay = 0.01          -- Delay between points (s)
local current_limit = 0.0001       -- Compliance (A)

-- ===== DATA FILE =====
local filename = "/usb1/ultralow_dual_sweep_iv_ALD15_TiPt_02.csv"
local file = io.open(filename, "w")

if not file then
    print("USB not accessible, using internal memory...")
    filename = "dual_sweep_iv.csv"
    file = io.open(filename, "w")
end

if file then
    file:write("Vmax,Voltage_V,Current_A,Direction\n")
    print("Data will be saved to: " .. filename)
end

-- ===== CONFIGURE SMU =====
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = current_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.source.output = smu.ON

print("Dual Sweep DC I-V Started")
print("Vmax, Voltage(V), Current(A), Direction")

-- ===== SWEEP FOR EACH VOLTAGE =====
for v_max = v_start, v_end, v_step do
    
    print(string.format("=== Sweeping Vmax = %.2f V ===", v_max))
    
    -- FORWARD SWEEP: 0 -> +Vmax
    for v = 0, v_max, sweep_step do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        
        local line = string.format("%.2f,%.3f,%.6e,FWD", v_max, v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    -- REVERSE SWEEP: +Vmax -> 0
    for v = v_max, 0, -sweep_step do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        
        local line = string.format("%.2f,%.3f,%.6e,REV", v_max, v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    -- FORWARD SWEEP: 0 -> -Vmax
    for v = 0, -v_max, -sweep_step do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        
        local line = string.format("%.2f,%.3f,%.6e,FWD_NEG", v_max, v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    -- REVERSE SWEEP: -Vmax -> 0
    for v = -v_max, 0, sweep_step do
        smu.source.level = v
        delay(sweep_delay)
        local i = smu.measure.read()
        
        local line = string.format("%.2f,%.3f,%.6e,REV_NEG", v_max, v, i)
        print(line)
        if file then file:write(line .. "\n") end
    end
    
    print(string.format("Vmax = %.2f V complete", v_max))
    delay(0.1)
end

-- ===== CLEANUP =====
smu.source.level = 0
smu.source.output = smu.OFF

if file then
    file:close()
    print("Data saved to: " .. filename)
end

print("Dual sweep DC I-V complete")