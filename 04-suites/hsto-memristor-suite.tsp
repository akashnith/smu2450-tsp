-- ============================================================================
-- FILE   : HfSrTiO2_Measurements_2450.tsp
-- INSTR  : Keithley 2450 SourceMeter (TSP / Lua)
-- ============================================================================

reset()

-- ============================================================================
--  GLOBAL CONFIGURATION
-- ============================================================================
local USB             = "/usb1/"
local SAMPLE_ID       = "HZO_ALD15tipt_10nm"

smu.measure.terminals = smu.TERMINALS_REAR

local V_RANGE         = 3
local I_COMPL         = 100e-3
local NPLC            = 1
local SWEEP_DELAY     = 0.01
local SENSE_DELAY     = 0.001

local V_READ          = 0.1
local V_READ_I        = 0.1

local V_SET           = 3.5
local V_RST           = -3.5
local T_PW            = 2e-3
local T_OFF           = 5e-3

local RETENTION_MAX   = 1000
local RETENTION_INT   = 1

-- ============================================================================
--  LOW-LEVEL SMU HELPERS
-- ============================================================================

local function smu_init(compliance)
    compliance              = compliance or I_COMPL
    smu.source.func         = smu.FUNC_DC_VOLTAGE
    smu.measure.func        = smu.FUNC_DC_CURRENT
    smu.source.range        = V_RANGE
    smu.source.ilimit.level = compliance
    smu.measure.autorange   = smu.ON
    smu.measure.nplc        = NPLC
    smu.source.level        = 0
    smu.source.output       = smu.ON
end

local function smu_off()
    smu.source.level = 0
    delay(0.01)
    smu.source.output = smu.OFF
end

local function vmeas(v)
    smu.source.level = v
    delay(SENSE_DELAY)
    return smu.measure.read()
end

local function calc_R(v, i)
    if math.abs(i) < 1e-14 then return 1e15 end
    return v / i
end

local function comp_flag()
    if smu.source.compliance then return "YES" else return "NO" end
end

local function pulse(v_amp, t_width, t_gap)
    smu.source.level = v_amp
    delay(t_width)
    smu.source.level = 0
    delay(t_gap)
end

local function open_file(path)
    local f = io.open(path, "w")
    if not f then
        print("ERROR: Cannot open " .. path .. "  – check USB drive!")
    end
    return f
end

local function fpath(tag)
    return USB .. SAMPLE_ID .. "_" .. tag .. ".csv"
end

local function banner(title)
    print("")
    print("================================================")
    print("  " .. title)
    print("================================================")
end

-- ============================================================================
--  MEASUREMENT FUNCTIONS
-- ============================================================================

local function M01_basic_iv(n_cycles, v_max, step)
    n_cycles   = 100
    v_max      = 3
    step       = 0.05

    local tag  = "M01_BasicIV_" .. n_cycles .. "cyc"
    local path = fpath(tag)
    banner("M01 – Basic I-V Sweep | " .. n_cycles .. " cycles | Vmax=" .. v_max .. "V")

    local f = open_file(path)
    if not f then return end
    f:write("Cycle,Segment,Voltage_V,Current_A,Resistance_Ohm,Compliance\n")

    smu_init()

    for cyc = 1, n_cycles do
        local v = 0
        while v <= v_max + 1e-9 do
            local i = vmeas(v)
            f:write(string.format("%d,POS_FWD,%.6e,%.6e,%.6e,%s\n", cyc, v, i, calc_R(v, i), comp_flag()))
            v = v + step
        end
        v = v_max
        while v >= -1e-9 do
            local i = vmeas(v)
            f:write(string.format("%d,POS_REV,%.6e,%.6e,%.6e,%s\n", cyc, v, i, calc_R(v, i), comp_flag()))
            v = v - step
        end
        v = 0
        while v >= -v_max - 1e-9 do
            local i = vmeas(v)
            f:write(string.format("%d,NEG_FWD,%.6e,%.6e,%.6e,%s\n", cyc, v, i, calc_R(v, i), comp_flag()))
            v = v - step
        end
        v = -v_max
        while v <= 1e-9 do
            local i = vmeas(v)
            f:write(string.format("%d,NEG_REV,%.6e,%.6e,%.6e,%s\n", cyc, v, i, calc_R(v, i), comp_flag()))
            v = v + step
        end

        local i_rd = vmeas(V_READ)
        smu.source.level = 0
        print(string.format("  Cycle %3d/%d  |  R_read = %.3e Ohm", cyc, n_cycles, math.abs(calc_R(V_READ, i_rd))))
    end

    f:close()
    smu_off()
end

local function M02_device_uniformity(n_devices, n_cycles, v_max, step)
    n_devices  = n_devices or 50
    n_cycles   = n_cycles or 50
    v_max      = v_max or 3.5
    step       = step or 0.05

    local path = fpath("M02_DeviceUniformity")
    banner("M02 – Device-to-Device Uniformity")

    local f = open_file(path)
    if not f then return end
    f:write("Device,Cycle,LRS_R_Ohm,HRS_R_Ohm,Window\n")

    for dev = 1, n_devices do
        print(string.format("  >>> MOVE PROBE TO DEVICE %d / %d  <<<", dev, n_devices))
        smu_off()
        delay(3.0)
        smu_init()

        local lrs_sum, hrs_sum = 0, 0

        for cyc = 1, n_cycles do
            local v = 0
            while v <= v_max + 1e-9 do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
            end
            v = v_max
            while v >= -1e-9 do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
            end
            local i_lrs = vmeas(V_READ); smu.source.level = 0
            local R_lrs = math.abs(calc_R(V_READ, i_lrs))

            v = 0
            while v >= -v_max - 1e-9 do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
            end
            v = -v_max
            while v <= 1e-9 do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
            end
            local i_hrs = vmeas(V_READ); smu.source.level = 0
            local R_hrs = math.abs(calc_R(V_READ, i_hrs))

            lrs_sum = lrs_sum + R_lrs
            hrs_sum = hrs_sum + R_hrs
            f:write(string.format("%d,%d,%.4e,%.4e,%.3f\n", dev, cyc, R_lrs, R_hrs, R_hrs / R_lrs))
        end
        print(string.format("  Dev %d done", dev))
    end
    f:close()
    smu_off()
end

local function M03_endurance_iv(n_cycles, v_max, step)
    n_cycles   = 1100
    v_max      = v_max or 3.5
    step       = step or 0.05
    local path = fpath("M03_Endurance_IV")
    banner("M03 – Endurance (I-V)")
    local f = open_file(path)
    if not f then return end
    f:write("Cycle,LRS_R_Ohm,HRS_R_Ohm,Window\n")
    smu_init()
    for cyc = 1, n_cycles do
        local v = 0
        while v <= v_max + 1e-9 do
            smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
        end
        v = v_max
        while v >= -1e-9 do
            smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
        end
        local i_lrs = vmeas(V_READ); local R_lrs = math.abs(calc_R(V_READ, i_lrs))

        v = 0
        while v >= -v_max - 1e-9 do
            smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
        end
        v = -v_max
        while v <= 1e-9 do
            smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
        end
        local i_hrs = vmeas(V_READ); local R_hrs = math.abs(calc_R(V_READ, i_hrs))
        f:write(string.format("%d,%.4e,%.4e,%.3f\n", cyc, R_lrs, R_hrs, R_hrs / R_lrs))
        if (cyc - math.floor(cyc / 100) * 100 == 0) then print("Cycle " .. cyc) end
    end
    f:close()
    smu_off()
end

local function M04_endurance_pulse(n_cycles, read_every)
    n_cycles   = 5000
    read_every = 50
    local path = fpath("M04_Endurance_Pulse")
    banner("M04 – Endurance (Pulse)")
    local f = open_file(path)
    if not f then return end
    f:write("Cycle,LRS_R_Ohm,HRS_R_Ohm,Window\n")
    smu_init()
    smu.measure.nplc = 0.1
    for cyc = 1, n_cycles do
        pulse(V_SET, T_PW, T_OFF)
        pulse(V_RST, T_PW, T_OFF)
        if (cyc - math.floor(cyc / read_every) * read_every == 0) then
            pulse(V_SET, T_PW, T_OFF)
            local i_lrs = vmeas(V_READ)
            pulse(V_RST, T_PW, T_OFF)
            local i_hrs = vmeas(V_READ)
            f:write(string.format("%d,%.4e,%.4e,%.3f\n", cyc, math.abs(calc_R(V_READ, i_lrs)),
                math.abs(calc_R(V_READ, i_hrs)), math.abs(i_lrs / i_hrs)))
        end
    end
    smu.measure.nplc = NPLC
    f:close()
    smu_off()
end

local function M05_retention_binary()
    local path = fpath("M05_Retention_Binary")
    banner("M05 – Binary Retention")
    local f = open_file(path)
    if not f then return end
    f:write("State,Time_s,Current_A,Resistance_Ohm\n")
    smu_init()
    pulse(V_SET, T_PW, T_OFF)
    local t_start = os.time()
    local t = 0
    while t < RETENTION_MAX do
        local i = vmeas(V_READ); t = os.time() - t_start
        f:write(string.format("LRS,%.1f,%.6e,%.6e\n", t, i, math.abs(calc_R(V_READ, i))))
        delay(RETENTION_INT)
    end
    pulse(V_RST, T_PW, T_OFF)
    t_start = os.time(); t = 0
    while t < RETENTION_MAX do
        local i = vmeas(V_READ); t = os.time() - t_start
        f:write(string.format("HRS,%.1f,%.6e,%.6e\n", t, i, math.abs(calc_R(V_READ, i))))
        delay(RETENTION_INT)
    end
    f:close()
    smu_off()
end

local function M06_multivoltage_iv(n_cycles_each, step)
    n_cycles_each = 50
    step          = 0.05
    local path    = fpath("M06_MultiVoltage_IV")
    local f       = open_file(path)
    if not f then return end
    smu_init()
    local vp = 0.75
    while vp <= 3.505 do
        for cyc = 1, n_cycles_each do
            local v = 0
            while v <= vp do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
            end
            local i_lrs = vmeas(V_READ)
            v = 0
            while v >= -vp do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
            end
            local i_hrs = vmeas(V_READ)
            f:write(string.format("%.2f,%d,%.4e,%.4e\n", vp, cyc, math.abs(calc_R(V_READ, i_lrs)),
                math.abs(calc_R(V_READ, i_hrs))))
        end
        vp = vp + 0.25
    end
    f:close()
    smu_off()
end

local function M07_electrode_size(n_devices, v_max, step)
    n_devices = 50; v_max = 3.5; step = 0.05
    local sizes = { 25, 50, 100 }
    for _, dte in ipairs(sizes) do
        local f = open_file(fpath("M07_Size_" .. dte))
        smu_init()
        for dev = 1, n_devices do
            print("Size " .. dte .. " Device " .. dev); smu_off(); delay(2.0); smu_init()
            local v = 0
            while v <= v_max do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v + step
            end
            local i_lrs = vmeas(V_READ_I)
            v = 0
            while v >= -v_max do
                smu.source.level = v; delay(SWEEP_DELAY); smu.measure.read(); v = v - step
            end
            local i_hrs = vmeas(V_READ_I)
            f:write(string.format("%d,%.4e,%.4e\n", dev, math.abs(calc_R(V_READ_I, i_lrs)),
                math.abs(calc_R(V_READ_I, i_hrs))))
        end
        f:close()
    end
end

local function M08_identical_spikes(n_spikes, dt_ms, amplitudes)
    n_spikes = 100; dt_ms = 5.0; amplitudes = { 1.0, 2.0, 3.0 }
    local f = open_file(fpath("M08_Identical"))
    smu_init(); smu.measure.nplc = 0.1
    for _, amp in ipairs(amplitudes) do
        for k = 1, n_spikes do
            pulse(amp, dt_ms * 1e-3, dt_ms * 1e-3)
            local i = vmeas(V_READ); f:write(string.format("%.1f,POT,%d,%.6e\n", amp, k, i / V_READ))
        end
        for k = 1, n_spikes do
            pulse(-amp, dt_ms * 1e-3, dt_ms * 1e-3)
            local i = vmeas(V_READ); f:write(string.format("%.1f,DEP,%d,%.6e\n", amp, k, i / V_READ))
        end
    end
    f:close(); smu_off()
end

local function M09_long_spike_training(spike_counts, v_amp, dt_ms)
    v_amp = 1.0; dt_ms = 2.0; spike_counts = { 100, 500, 1000, 6000, 12000 }
    smu_init(); smu.measure.nplc = 0.1
    for _, n_spk in ipairs(spike_counts) do
        local f = open_file(fpath("M09_Long_" .. n_spk))
        for k = 1, n_spk do
            pulse(v_amp, dt_ms * 1e-3, dt_ms * 1e-3); f:write("POT," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n")
        end
        for k = 1, n_spk do
            pulse(-v_amp, dt_ms * 1e-3, dt_ms * 1e-3); f:write("DEP," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n")
        end
        f:close()
    end
    smu_off()
end

local function M10_multilevel_retention(n_levels, spikes_per_lev, v_amp, dt_ms, retain_s)
    n_levels = 3; spikes_per_lev = 20; v_amp = 1.0; dt_ms = 2.0; retain_s = 300
    local f = open_file(fpath("M10_MultiReten"))
    smu_init()
    for lev = 1, n_levels do
        for _ = 1, spikes_per_lev do pulse(v_amp, dt_ms * 1e-3, dt_ms * 1e-3) end
        local t0 = os.time()
        local t = 0
        while t < retain_s do
            local i = vmeas(V_READ); t = os.time() - t0
            f:write(lev .. "," .. t .. "," .. i / V_READ .. "\n"); delay(1.0)
        end
    end
    f:close(); smu_off()
end

local function M11_variable_dt(v_amp, dt_start, dt_stop, dt_step_ms, n_spikes)
    v_amp = 1.0; dt_start = 2.0; dt_stop = 500.0; dt_step_ms = 10.0; n_spikes = 30
    local f = open_file(fpath("M11_VarDT"))
    smu_init()
    local dt = dt_start
    while dt <= dt_stop do
        for k = 1, n_spikes do
            pulse(v_amp, dt * 1e-3, dt * 1e-3); f:write(dt .. ",POT," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n")
        end
        for k = 1, n_spikes do
            pulse(-v_amp, dt * 1e-3, dt * 1e-3); f:write(dt .. ",DEP," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n")
        end
        dt = dt + dt_step_ms
    end
    f:close(); smu_off()
end

local function M12_nonidentical_spikes(dt_ms)
    dt_ms = 2.0; local f = open_file(fpath("M12_NonIdentical"))
    smu_init()
    for a = 0.6, 3.0, 0.1 do
        pulse(a, dt_ms * 1e-3, dt_ms * 1e-3); f:write("POT," .. a .. "," .. vmeas(V_READ) / V_READ .. "\n")
    end
    for a = 0.6, 3.0, 0.1 do
        pulse(-a, dt_ms * 1e-3, dt_ms * 1e-3); f:write("DEP," .. a .. "," .. vmeas(V_READ) / V_READ .. "\n")
    end
    f:close(); smu_off()
end

local function M13_operational_stability(total_spikes, v_amp, dt_ms, report_every)
    total_spikes = 40000; v_amp = 1.0; dt_ms = 2.0; report_every = 100
    local f = open_file(fpath("M13_Stability"))
    smu_init()
    for k = 1, total_spikes / 2 do
        pulse(v_amp, dt_ms * 1e-3, dt_ms * 1e-3)
        if (k - math.floor(k / report_every) * report_every == 0) then f:write("POT," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n") end
    end
    for k = 1, total_spikes / 2 do
        pulse(-v_amp, dt_ms * 1e-3, dt_ms * 1e-3)
        if (k - math.floor(k / report_every) * report_every == 0) then f:write("DEP," .. k .. "," .. vmeas(V_READ) / V_READ .. "\n") end
    end
    f:close(); smu_off()
end

local function M14_ppf_ppd(v_amp, dtpp_list, n_repeats)
    v_amp = 1.0; n_repeats = 5; dtpp_list = { 1, 2, 5, 10, 20, 40, 80 }
    local f = open_file(fpath("M14_PPF"))
    smu_init(); smu.measure.nplc = 0.01
    for _, dtpp in ipairs(dtpp_list) do
        for rep = 1, n_repeats do
            smu.source.level = v_amp; delay(T_PW); local i1 = smu.measure.read()
            smu.source.level = 0; delay(dtpp * 1e-3)
            smu.source.level = v_amp; delay(T_PW); local i2 = smu.measure.read()
            smu.source.level = 0; delay(0.01); f:write("PPF," .. dtpp .. "," .. rep .. "," .. i1 .. "," .. i2 .. "\n")
        end
    end
    f:close(); smu_off()
end

local function _apply_stdp_waveform(dt_s, v_peak, rise_s, fall_s, similar_pol)
    local dt_step = 0.5e-3
    local spike_w = rise_s + fall_s
    local t_total = 2 * spike_w + math.abs(dt_s) + 5e-3
    local n_steps = math.floor(t_total / dt_step)
    local t_pre = spike_w / 2; local t_post = t_pre + dt_s

    local function tri(t, tc)
        local tau = t - tc
        if tau >= -rise_s and tau < 0 then
            return v_peak * (1.0 + tau / rise_s)
        elseif tau >= 0 and tau <= fall_s then
            return v_peak * (1.0 - tau / fall_s)
        else
            return 0.0
        end
    end

    for k = 0, n_steps do
        local t = k * dt_step; local v_sum = similar_pol and (tri(t, t_pre) - tri(t, t_post)) or
        (tri(t, t_pre) + tri(t, t_post))
        smu.source.level = v_sum; delay(dt_step)
    end
    smu.source.level = 0
end

local function M15_M16_stdp(similar_pol, n_avg, v_peak, delta_t_list)
    n_avg = 50; v_peak = 1.0; delta_t_list = { -60, -40, -20, -10, -5, -2, -1, 1, 2, 5, 10, 20, 40, 60 }
    local f = open_file(fpath("STDP_" .. (similar_pol and "Sim" or "Opp")))
    smu_init()
    for _, dt_ms in ipairs(delta_t_list) do
        for rep = 1, n_avg do
            local g1 = vmeas(V_READ) / V_READ
            _apply_stdp_waveform(dt_ms * 1e-3, v_peak, 5e-3, 5e-3, similar_pol)
            local g2 = vmeas(V_READ) / V_READ
            f:write(dt_ms .. "," .. rep .. "," .. g1 .. "," .. g2 .. "\n")
        end
    end
    f:close(); smu_off()
end


-- ============================================================================
--  MAIN EXECUTION SEQUENCE

-- ============================================================================

print("========================================")
print("  HfSrTiO2 Neuromorphic Measurement Suite")
print("  Keithley 2450  |  TSP Script")
print("  All data saved to USB → /usb1/")
print("========================================")
print("Sample ID : " .. SAMPLE_ID)
print("USB path  : " .. USB)
print("")

-- ── M01 : Basic I-V, 30 cycles ──────────────────────────────────────────────
M01_basic_iv(90, 3.5, 0.05)

-- ── M02 : Device-to-device uniformity ───────────────────────────────────────
M02_device_uniformity(50, 50, 3.5, 0.05)

-- ── M03 : Endurance (I-V), 1100 cycles ──────────────────────────────────────
M03_endurance_iv(1100, 3.5, 0.05)

-- ── M04 : Endurance (Pulse), 50 000 cycles ──────────────────────────────────
M04_endurance_pulse(50000, 500)

-- ── M05 : Binary retention (set RETENTION_MAX above for full 5e5 s test) ────
M05_retention_binary()

-- ── M06 : Multi-voltage I-V ──────────────────────────────────────────────────
M06_multivoltage_iv(50, 0.05)

-- ── M07 : Electrode-size I-V ─────────────────────────────────────────────────
M07_electrode_size(50, 3.5, 0.05)

-- ── M08 : Identical-spike training ───────────────────────────────────────────
M08_identical_spikes(30, 1.0, { 1.0, 2.0, 3.0 })

-- ── M09 : Long spike training ────────────────────────────────────────────────
M09_long_spike_training({ 100, 500, 1000, 6000, 12000 }, 1.0, 1.0)

-- ── M10 : Multilevel retention ───────────────────────────────────────────────
M10_multilevel_retention(3, 20, 1.0, 1.0, 300)

-- ── M11 : Variable dt scheme ─────────────────────────────────────────────────
M11_variable_dt(1.0, 1.0, 30.0, 1.0, 30)

-- ── M12 : Non-identical spike scheme ─────────────────────────────────────────
M12_nonidentical_spikes(1.0)

-- ── M13 : Operational stability (40 000 spikes) ──────────────────────────────
M13_operational_stability(40000, 1.0, 1.0, 100)

-- ── M14 : PPF / PPD ──────────────────────────────────────────────────────────
M14_ppf_ppd(1.0, { 1, 2, 5, 10, 20, 40, 80 }, 5)

-- ── M15 : STDP – similar polarity ────────────────────────────────────────────
M15_M16_stdp(true, 50, 1.0, { -60, -40, -20, -10, -5, -2, -1, 1, 2, 5, 10, 20, 40, 60 })

-- ── M16 : STDP – opposite polarity ───────────────────────────────────────────
M15_M16_stdp(false, 50, 1.0, { -60, -40, -20, -10, -5, -2, -1, 1, 2, 5, 10, 20, 40, 60 })

-- ============================================================================
smu.source.level  = 0
smu.source.output = smu.OFF

print("")
print("========================================")
print("  ALL MEASUREMENTS COMPLETE")
print("  Data saved to USB  /usb1/")
print("  Safe to disconnect device.")
print("========================================")
-- ============================================================================
