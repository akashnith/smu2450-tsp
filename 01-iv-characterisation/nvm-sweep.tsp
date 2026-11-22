
-- =======================================================
-- HIGH-RES NVM CHARACTERIZATION (Microvolt Steps)
-- Hardware: Keithley 2450
-- =======================================================

reset()

-- 1. SETUP
-- ========
local sample_name = "NVM_Device_ALD14_TiPt_01"
smu.measure.terminals = smu.TERMINALS_REAR
smu.source.func = smu.FUNC_DC_VOLTAGE

-- Compliance (Critical for RS)
smu.source.ilimit.level = 100e-6  

smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 0.01 --PLC (Standard Low Noise)

-- Voltage Sweep List: {Vmax (V), Step (V)}
-- UPDATED: Steps are now in Microvolts (e-6)
local sweep_list = {
    {0.5, 20e-6},   -- 20 uV step (High Res)
    {1.0, 40e-6},   -- 40 uV step
    {1.5, 80e-6},   -- 80 uV step
    {2.0, 100e-6}   -- 100 uV step
}

local ideal_delay = 0.01 

-- 2. CORE FUNCTION
-- ================
function run_dual_sweep(v_target, step_size, is_pos_first)
    
    local dir_tag = is_pos_first and "PosFirst" or "NegFirst"
    local fname = string.format("/usb1/%s_%s_V%.1f.csv", 
                                sample_name, dir_tag, v_target)
    
    print(string.format("\n=== Starting V=%.1f (%s) ===", v_target, dir_tag))
    print(string.format("Step Size: %.1f uV (Huge dataset warning)", step_size*1e6))
    
    local f = io.open(fname, "w")
    if not f then
        print("Error: USB not detected")
        return
    end
    f:write("Voltage_V,Current_A,Direction\n")

    smu.source.output = smu.ON
    
    -- Sequence Definitions
    local legs = {}
    if is_pos_first then
        legs = {
            {start=0, stop=v_target, step=step_size, tag="FWD_POS"},
            {start=v_target, stop=0, step=-step_size, tag="REV_POS"},
            {start=0, stop=-v_target, step=-step_size, tag="FWD_NEG"},
            {start=-v_target, stop=0, step=step_size, tag="REV_NEG"}
        }
    else
        legs = {
            {start=0, stop=-v_target, step=-step_size, tag="FWD_NEG"},
            {start=-v_target, stop=0, step=step_size, tag="REV_NEG"},
            {start=0, stop=v_target, step=step_size, tag="FWD_POS"},
            {start=v_target, stop=0, step=-step_size, tag="REV_POS"}
        }
    end

    -- Run Legs
    for _, leg in ipairs(legs) do
        local range = math.abs(leg.stop - leg.start)
        local count = math.floor(range / math.abs(leg.step))
        
        for i = 0, count do
            local v_set = leg.start + (i * leg.step)
            if math.abs(v_set) > math.abs(v_target) then v_set = leg.stop end
            
            smu.source.level = v_set
            delay(ideal_delay)
            local i_meas = smu.measure.read()
            
            -- SAVE to USB
            f:write(string.format("%.6f,%.6e,%s\n", v_set, i_meas, leg.tag))
            
            -- PRINT to Terminal (Live View)
            -- Shows: V: 0.123456 | I: 1.23e-06
            print(string.format("V: %.6f | I: %.3e", v_set, i_meas))
        end
    end

    smu.source.level = 0
    smu.source.output = smu.OFF
    f:close()
    print("Saved: " .. fname)
end

-- 3. EXECUTION
-- ============
print("=== High-Res NVM Characterization ===")

for _, cfg in ipairs(sweep_list) do
    local v_max = cfg[1]
    local v_step = cfg[2]
    
    run_dual_sweep(v_max, v_step, true)   -- Pos First
    delay(2.0)
    run_dual_sweep(v_max, v_step, false)  -- Neg First
    delay(2.0)
end

print("=== COMPLETE ===")