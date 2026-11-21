--[[
    Resistive Switching Adaptive Dual Sweep (FIXED)
    Instrument: Keithley 2450
    Author: akash
    Date: 2026-01-23
]]

-- ================= CONFIGURATION =================
local filename = "/usb1/Adaptive_RS_Data.csv"
local icc_base = 100e-6       
local short_check_v = 0.1     
local search_step = 0.01      
local search_limit = 2.0      
local num_points = 201        

-- 1. GLOBAL RESET & CALIBRATION
reset()
errorqueue.clear()

-- Enable Internal Auto Zero (Crucial for <100uA accuracy)
smu.measure.autozero.enable = smu.ON 
-- Note: This doubles measurement time but removes thermal drift.

-- Setup Buffers
local def_buf = defbuffer1
def_buf.clear()
def_buf.capacity = 20000 

-- Setup Source/Measure
smu.terminals = smu.TERMINAL_REAR
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.autorange = smu.ON
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.terminals = smu.TERMINAL_REAR

-- Helper: Create Dual Sweep Points (0 -> V -> 0 -> -V -> 0)
function get_dual_sweep_points(v_max, points)
    local list_v = {}
    local steps_per_leg = math.floor(points / 4)
    local v_step = v_max / steps_per_leg
    
    for i = 0, steps_per_leg do table.insert(list_v, i * v_step) end
    for i = 1, steps_per_leg do table.insert(list_v, v_max - (i * v_step)) end
    for i = 1, steps_per_leg do table.insert(list_v, -(i * v_step)) end
    for i = 1, steps_per_leg do table.insert(list_v, -v_max + (i * v_step)) end
    
    return list_v
end

-- Helper: Run Sweep from List
function run_sweep_list(v_list, icc, tag_str)
    smu.source.ilimit.level = icc
    
    -- FIXED LINE: Used table.getn() instead of # operator
    local v_max_debug = math.abs(v_list[math.floor(table.getn(v_list)/4) + 1])
    print("Running Sweep: " .. tag_str .. " | Vmax: " .. string.format("%.3f", v_max_debug) .. " | Icc: " .. icc)
    
    for i = 1, table.getn(v_list) do
        smu.source.level = v_list[i]
        delay(0.001) 
        smu.measure.read(def_buf)
    end
end

-- ================= MAIN LOGIC =================

-- 2. SHORT CHECK
smu.source.ilimit.level = icc_base
smu.source.level = short_check_v
delay(0.2) -- Increased delay for Auto-Zero settling
local i_short = smu.measure.read()
smu.source.level = 0

if math.abs(i_short) >= (0.95 * icc_base) then
    display.changescreen(display.SCREEN_USER_USER)
    display.settext(display.TEXT1, "SHORT DETECTED")
    display.settext(display.TEXT2, string.format("I = %.2f uA", i_short*1e6))
    print("Short detected. Aborting.")
    exit()
else
    print("Short Check Passed. I = " .. i_short)
end

-- 3. FIND Vi (Search for 100uA)
print("Searching for Vi (Target 100uA)...")
local found_vi = 0
local v_search = 0
local triggered = false

-- Positive Search
while v_search < search_limit do
    v_search = v_search + search_step
    smu.source.level = v_search
    delay(0.005)
    if math.abs(smu.measure.read()) >= icc_base then
        found_vi = v_search
        triggered = true
        break
    end
end
smu.source.level = 0

-- Negative Search (if not found in positive)
if not triggered then
    v_search = 0
    while v_search > -search_limit do
        v_search = v_search - search_step
        smu.source.level = v_search
        delay(0.005)
        if math.abs(smu.measure.read()) >= icc_base then
            found_vi = math.abs(v_search)
            triggered = true
            break
        end
    end
end
smu.source.level = 0

if not triggered then
    print("Could not find Vi within limit. Using default 1V.")
    found_vi = 1.0
end

print("Found Vi: " .. found_vi .. " V")

-- 4. EXECUTE MEASUREMENT PLAN
if found_vi < 0.1 then
    -- === CASE A: ULTRA-LOW SWITCHING (<100mV) ===
    print("Mode: Ultra-Low Voltage (<100mV)")
    
    local list_vi = get_dual_sweep_points(found_vi, num_points)
    run_sweep_list(list_vi, icc_base, "Base_Vi_Sweep")
    
    local var_voltages = {0.05, 0.1, 0.2, 0.3, 0.4, 0.5}
    local var_icc = 500e-6
    
    for _, v_target in ipairs(var_voltages) do
        local pts = get_dual_sweep_points(v_target, num_points)
        run_sweep_list(pts, var_icc, "Var_" .. (v_target*1000) .. "mV")
    end

else
    -- === CASE B: STANDARD SWITCHING (>=100mV) ===
    print("Mode: Standard Voltage (>=100mV)")
    
    local list_vi = get_dual_sweep_points(found_vi, num_points)
    run_sweep_list(list_vi, icc_base, "Base_Vi_Sweep")
    
    local steps = {
        {0.5, 200e-6},
        {1.0, 300e-6},
        {1.5, 400e-6},
        {2.0, 500e-6}
    }
    
    for _, step in ipairs(steps) do
        local v_target = step[1]
        local i_target = step[2]
        local pts = get_dual_sweep_points(v_target, num_points)
        run_sweep_list(pts, i_target, "Var_" .. (v_target) .. "V")
    end
end

smu.source.output = smu.OFF

-- ================= SAVE TO USB =================
print("Saving to USB: " .. filename)
local file_id = file.open(filename, file.WRITE)
file.write(file_id, "Voltage,Current\n")

for i = 1, def_buf.n do
    file.write(file_id, string.format("%g,%g\n", def_buf.sourcevalues[i], def_buf[i]))
end

file.close(file_id)
print("Done.")
display.settext(display.TEXT1, "Done")
display.settext(display.TEXT2, "Saved to USB")