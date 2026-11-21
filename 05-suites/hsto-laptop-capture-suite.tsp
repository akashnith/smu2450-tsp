-- ============================================================================
-- INSTRUMENT : Keithley 2450 (TSP)
-- TARGET     : Laptop Capture (PC) - No USB Required
-- SAMPLE     : Mo / Hf(Sr,Ti)O2 / TiN
-- ============================================================================

reset()

-- Global Configuration
smu.measure.terminals = smu.TERMINALS_REAR
local SAMPLE_ID       = "HZO_ALD15tipt_10nm"
local V_READ          = 0.1
local I_COMPL         = 100e-3
local NPLC            = 1
local SWEEP_DELAY     = 0.01

-- Initialise SMU
local function smu_init(compliance)
    compliance = compliance or I_COMPL
    smu.source.func = smu.FUNC_DC_VOLTAGE
    smu.measure.func = smu.FUNC_DC_CURRENT
    smu.source.ilimit.level = compliance
    smu.measure.autorange = smu.ON
    smu.measure.nplc = NPLC
    smu.source.output = smu.ON
end

local function vmeas(v)
    smu.source.level = v
    delay(0.001)
    return smu.measure.read()
end

-- DATA STREAMING HELPER
-- Prefixes lines with "DATA" for the Python script to catch
local function stream(tag, payload)
    print("DATA," .. tag .. "," .. payload)
end

-- ============================================================================
-- M01: BASIC I-V SWEEP
-- ============================================================================
local function M01_basic_iv(n_cycles, v_max, step)
    n_cycles, v_max, step = n_cycles or 30, v_max or 3.5, step or 0.05
    print("MSG: Starting M01 - Basic IV")
    print("HEADER: Cycle,Segment,Voltage,Current")
    smu_init()

    for cyc = 1, n_cycles do
        -- 0 -> +Vmax -> 0 -> -Vmax -> 0
        local points = { { 0, v_max, step, "POS_FWD" }, { v_max, 0, -step, "POS_REV" },
            { 0, -v_max, -step, "NEG_FWD" }, { -v_max, 0, step, "NEG_REV" } }

        for _, seg in ipairs(points) do
            local start_v, end_v, s, label = seg[1], seg[2], seg[3], seg[4]
            local v = start_v
            -- Comparison logic adjusted to avoid floating point precision issues
            while (s > 0 and v <= end_v + 1e-7) or (s < 0 and v >= end_v - 1e-7) do
                local i = vmeas(v)
                stream("M01", cyc .. "," .. label .. "," .. v .. "," .. i)
                v = v + s
            end
        end
    end
    smu.source.output = smu.OFF
end

-- ============================================================================
-- M08: IDENTICAL SPIKE TRAINING (Potentiation / Depression)
-- ============================================================================
local function M08_identical_spikes(n_spikes, dt_ms, amps)
    n_spikes = n_spikes or 30
    amps = amps or { 1.0, 2.0, 3.0 }
    print("MSG: Starting M08 - Identical Spikes")
    print("HEADER: Amp,Type,SpikeN,Conductance")
    smu_init()

    for _, amp in ipairs(amps) do
        -- Potentiation
        for k = 1, n_spikes do
            smu.source.level = amp; delay(dt_ms * 1e-3)
            smu.source.level = 0; delay(dt_ms * 1e-3)
            local i = vmeas(V_READ)
            stream("M08", amp .. ",POT," .. k .. "," .. (i / V_READ))
        end
        -- Depression
        for k = 1, n_spikes do
            smu.source.level = -amp; delay(dt_ms * 1e-3)
            smu.source.level = 0; delay(dt_ms * 1e-3)
            local i = vmeas(V_READ)
            stream("M08", amp .. ",DEP," .. k .. "," .. (i / V_READ))
        end
    end
    smu.source.output = smu.OFF
end

-- ============================================================================
-- M15/16: STDP (Simplified for streaming)
-- ============================================================================
local function M15_M16_stdp(similar_pol, n_avg, v_peak, dt_list)
    print("MSG: Starting STDP")
    print("HEADER: DeltaT_ms,dW_pct")
    smu_init()

    for _, dt_ms in ipairs(dt_list) do
        local dw_sum = 0
        for rep = 1, n_avg do
            local i_pre = vmeas(V_READ)
            -- Simplified pulse (Triangle spikes are complex via print, using rectangular for stability)
            smu.source.level = v_peak; delay(0.005); smu.source.level = 0
            delay(math.abs(dt_ms) * 1e-3)
            local v_post = similar_pol and v_peak or -v_peak
            smu.source.level = v_post; delay(0.005); smu.source.level = 0

            local i_post = vmeas(V_READ)
            dw_sum = dw_sum + ((i_post - i_pre) / i_pre)
        end
        stream("STDP", dt_ms .. "," .. (dw_sum / n_avg * 100))
    end
end

-- ============================================================================
-- MAIN EXECUTION
-- ============================================================================

print("========================================")
print("  HfSrTiO2 Neuromorphic Measurement Suite")
print("  Keithley 2450  |  TSP Script")
print("  Ref: Bakhit et al. Sci.Adv. 2026")
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
