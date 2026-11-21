-- =======================================================
-- SMART SCAN V4: High-Res Short Characterization
-- Hardware: Keithley 2450
-- =======================================================

reset()

-- 1. CONFIGURATION
-- ================
local base_name = "SmartScan_HighRes" 
smu.measure.terminals = smu.TERMINALS_REAR
smu.source.func = smu.FUNC_DC_VOLTAGE

-- COMPLIANCE
local icc_limit = 100e-6     -- 100 uA

-- SHORT CHARACTERIZATION SETTINGS
local v_short_target = 0.1   -- 100mV (V_shorted)
local v_short_step = 50e-6   -- 50uV step (High Resolution)

-- HEALTHY SCAN SETTINGS
local v_abs_max = 2.0        -- Max voltage for healthy scan
local v_scan_step = 20e-3    -- 20mV step for window finding

smu.source.ilimit.level = icc_limit
smu.measure.func = smu.FUNC_DC_CURRENT
smu.measure.autorange = smu.ON
smu.measure.nplc = 1.0       -- 1 PLC (Low Noise)

-- 2. HELPER: DIAGNOSTIC CHECK
-- ===========================
function check_sample_status()
    smu.source.output = smu.ON
    smu.source.level = v_short_target -- Check at 100mV
    delay(0.1)
    local i_check = smu.measure.read()
    smu.source.output = smu.OFF
    
    -- If Current > 90% of compliance, it is "Shorted/LRS"
    -- Or if resistance is very low.
    local is_short = math.abs(i_check) > (icc_limit * 0.9)
    return is_short, i_check
end

-- 3. HELPER: GENERIC DUAL SWEEP
-- =============================
function run_dual_sweep_points(f, v_target, step_size, tag_prefix)
    -- Dual Sweep: 0 -> +V -> 0 -> -V -> 0
    local legs = {
        {start=0, stop=v_target, step=step_size, tag="FWD_POS"},
        {start=v_target, stop=0, step=-step_size, tag="REV_POS"},
        {start=0, stop=-v_target, step=-step_size, tag="FWD_NEG"},
        {start=-v_target, stop=0, step=step_size, tag="REV_NEG"}
    }

    -- Calculate total points for progress display
    local pts_per_leg = math.abs(v_target / step_size)
    print(string.format("   ... High-Res Sweep: ~%d points per leg", pts_per_leg))

    for _, leg in ipairs(legs) do
        -- Calculate loop count carefully to hit target exactly
        local range = math.abs(leg.stop - leg.start)
        local count = math.floor(range / math.abs(leg.step))
        
        for i = 0, count do
            local v_set = leg.start + (i * leg.step)
            
            -- Clamp to target to prevent overshoot
            if math.abs(v_set) > math.abs(v_target) then v_set = leg.stop end
            
            smu.source.level = v_set
            -- No delay needed for fine steps (voltage change is tiny)
            local i_meas = smu.measure.read()
            
            f:write(string.format("%.6f,%.6e,%s_%s,RUN\n", v_set, i_meas, tag_prefix, leg.tag))
        end
    end
end

-- 4. HELPER: RESET ATTEMPT
-- ========================
function perform_reset_attempt(f, v_target, attempt_name)
    print(string.format("   >> %s: Sweeping to %.2f V...", attempt_name, v_target))
    local end_i = 0
    local steps = math.floor(math.abs(v_target) / 0.02)
    
    for k = 0, steps do
        local v_neg = -(k * 0.02)
        smu.source.level = v_neg
        delay(0.01)
        local im = smu.measure.read()
        f:write(string.format("%.4f,%.6e,RESET_%s,RUN\n", v_neg, im, attempt_name))
        if k == steps then end_i = math.abs(im) end
    end
    
    smu.source.level = 0
    return end_i < 20e-6 -- Success threshold (20uA)
end

-- 5. MAIN LOGIC
-- =============
function find_switching_window(sample_id)
    local fname = string.format("/usb1/%s_ID%03d.csv", base_name, sample_id)
    local f = io.open(fname, "w")
    
    if not f then print("Error: USB not ready") return end
    f:write("Voltage_V,Current_A,Phase,Status\n")
    print(string.format("\n=== SAMPLE ID: %03d ===", sample_id))

    -- A. DIAGNOSTIC
    local is_short, i_val = check_sample_status()

    smu.source.output = smu.ON

    if is_short then
        -- === PATH 1: SHORT CHARACTERIZATION (High-Res) ===
        print(string.format(">>> STATUS: SHORT DETECTED (I=%.2e)", i_val))
        print(string.format("   ... Running High-Res Char (+/- %.1f mV, %.0f uV step)", 
                            v_short_target*1000, v_short_step*1e6))
        
        -- Run the 0 -> +V -> 0 -> -V -> 0 sweep
        run_dual_sweep_points(f, v_short_target, v_short_step, "SHORT_CHAR")
        
        print(">>> RESULT: Characterization Complete.")
        f:write("0,0,RESULT,SHORT_CHAR_COMPLETE\n")
        
    else
        -- === PATH 2: HEALTHY PROGRESSIVE SCAN ===
        print(">>> STATUS: HEALTHY. Scanning for Switching Window...")
        
        local current_v_max = 0.2
        local set_success = false
        local set_voltage_point = 0
        
        while current_v_max <= v_abs_max do
            print(string.format("   ... Scan 0 -> %.1f V", current_v_max))
            
            local steps = math.floor(current_v_max / v_scan_step)
            for i = 0, steps do
                local v = i * v_scan_step
                smu.source.level = v
                delay(0.01)
                local im = smu.measure.read()
                f:write(string.format("%.4f,%.6e,SCAN_V%.1f,RUN\n", v, im, current_v_max))
                
                if math.abs(im) >= (icc_limit * 0.98) then
                    print(string.format("   !!! SET EVENT at %.2f V !!!", v))
                    set_success = true
                    set_voltage_point = v
                    break 
                end
            end
            
            smu.source.level = 0
            delay(0.1)
            
            if set_success then break end
            current_v_max = current_v_max + 0.2
        end
        
        -- If Set, Try Reset
        if set_success then
            local v_reset1 = -(set_voltage_point * 1.2)
            if v_reset1 > -0.8 then v_reset1 = -0.8 end
            
            if perform_reset_attempt(f, v_reset1, "ATTEMPT1") then
                print(">>> RESULT: OPTIMAL SWITCHING FOUND")
            else
                print("   !!! RETRYING RESET (Higher Voltage) !!!")
                if perform_reset_attempt(f, -2.5, "ATTEMPT2") then
                    print(">>> RESULT: RECOVERED on 2nd Attempt")
                else
                    print(">>> RESULT: STUCK SET")
                    f:write("0,0,RESULT,STUCK_SET\n")
                end
            end
        else
            print(">>> RESULT: NO SWITCHING (Device Open)")
        end
    end

    smu.source.output = smu.OFF
    f:close()
    print("File Saved.")
end

-- 6. RUN
-- ======
find_switching_window(1)