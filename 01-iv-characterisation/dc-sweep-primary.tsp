-- =======================================================
-- NVM Resistive Switching Characterization (Fresh Start)
-- Hardware: Keithley 2450
-- =======================================================

reset()

-- 1. SETUP & CONFIGURATION
-- ========================
local sample_name = "NVM_Device_01"
smu.measure.terminals = smu.TERMINALS_REAR
smu.source.func = smu.FUNC_DC_VOLTAGE
smu.source.ilimit.level = 100e-6  -- 100 uA Compliance
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 1.0            -- Integration time

-- Voltage Sweep List: {Vmax (V), Step (V)}
-- Note: Assumed mV (e.g., 20e-3) instead of uV for practical sweep times
local sweep_list = {
    {0.5, 20e-3},
    {1.0, 40e-3},
    {1.5, 80e-3},
    {2.0, 100e-3} 
}

-- Sweep Rates (Delay in seconds)
local rates = {
    {name="Fast", delay=0.001},
    {name="Med",  delay=0.01},
    {name="Slow", delay=0.1}
}

-- 2. CORE SWEEP FUNCTION
-- ======================
function run_dual_sweep(v_target, step_size, delay_time, speed_name, is_pos_first)
    
    -- Generate Filename
    local dir_tag = is_pos_first and "PosFirst" or "NegFirst"
    local fname = string.format("/usb1/%s_%s_V%.1f_%s.csv", 
                                sample_name, dir_tag, v_target, speed_name)
    
    print(string.format("Starting: %s (V=%.1f, %s)", dir_tag, v_target, speed_name))
    
    -- Open File
    local f = io.open(fname, "w")
    if f then
        f:write("Voltage_V,Current_A,Direction,Time_Sec\n")
    else
        print("Error: USB not detected or write protected")
        return
    end

    smu.source.output = smu.ON
    
    -- Define the 4 legs of the loop based on direction
    local legs = {}
    if is_pos_first then
        -- 0 -> +V -> 0 -> -V -> 0
        legs = {
            {start=0, stop=v_target, step=step_size, tag="FWD_POS"},
            {start=v_target, stop=0, step=-step_size, tag="REV_POS"},
            {start=0, stop=-v_target, step=-step_size, tag="FWD_NEG"},
            {start=-v_target, stop=0, step=step_size, tag="REV_NEG"}
        }
    else
        -- 0 -> -V -> 0 -> +V -> 0
        legs = {
            {start=0, stop=-v_target, step=-step_size, tag="FWD_NEG"},
            {start=-v_target, stop=0, step=step_size, tag="REV_NEG"},
            {start=0, stop=v_target, step=step_size, tag="FWD_POS"},
            {start=v_target, stop=0, step=-step_size, tag="REV_POS"}
        }
    end

    -- Execute Legs
    local t_start = os.clock()
    
    for _, leg in ipairs(legs) do
        -- Calculate number of steps to ensure precise endpoint
        local range = math.abs(leg.stop - leg.start)
        local count = math.floor(range / math.abs(leg.step))
        
        for i = 0, count do
            local v_set = leg.start + (i * leg.step)
            
            -- Clamp to avoid floating point overshoot
            if math.abs(v_set) > math.abs(v_target) then v_set = leg.stop end
            
            smu.source.level = v_set
            delay(delay_time)
            
            local i_meas = smu.measure.read()
            local t_now = os.clock() - t_start
            
            f:write(string.format("%.4f,%.6e,%s,%.3f\n", v_set, i_meas, leg.tag, t_now))
        end
    end

    smu.source.level = 0
    smu.source.output = smu.OFF
    f:close()
    print("Saved: " .. fname)
end

-- 3. MAIN EXECUTION LOOP
-- ======================
print("=== NVM Characterization Started ===")

-- Loop 1: Iterate Sweep Rates
for _, rate in ipairs(rates) do
    
    -- Loop 2: Iterate Voltage Levels
    for _, cfg in ipairs(sweep_list) do
        local v_max = cfg[1]
        local v_step = cfg[2]
        
        -- Run Positive First Sequence
        run_dual_sweep(v_max, v_step, rate.delay, rate.name, true)
        delay(1.0) -- Cooldown
        
        -- Run Negative First Sequence
        run_dual_sweep(v_max, v_step, rate.delay, rate.name, false)
        delay(1.0) -- Cooldown
    end
end

print("=== ALL SEQUENCES COMPLETE ===")