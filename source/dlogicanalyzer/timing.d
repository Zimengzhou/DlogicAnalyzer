module dlogicanalyzer.timing;

import dlogicanalyzer.waveform;
import dlogicanalyzer.levels;
import dlogicanalyzer.edges;

/// 周期性/一般波形的时序统计。
struct TimingStats
{
    double period;       /// 周期（秒）；非周期信号为 NaN
    double frequency;    /// 频率（Hz）；非周期信号为 NaN
    double dutyCycle;    /// 占空比 0..1；非周期信号为 NaN
    double avgHigh;      /// 平均高电平持续时间（秒）
    double avgLow;       /// 平均低电平持续时间（秒）
}

/// 由游程与上升沿推导时序统计。
TimingStats analyzeTiming(Waveform w) @safe pure
{
    TimingStats s;
    s.period = double.nan;
    s.frequency = double.nan;
    s.dutyCycle = double.nan;
    s.avgHigh = double.nan;
    s.avgLow = double.nan;

    Level[] segs = runs(w);
    if (segs.length == 0)
        return s;

    double sumHigh = 0, sumLow = 0;
    ulong nHigh = 0, nLow = 0;
    foreach (seg; segs)
    {
        if (seg.high)
        {
            sumHigh += seg.duration;
            nHigh++;
        }
        else
        {
            sumLow += seg.duration;
            nLow++;
        }
    }
    s.avgHigh = nHigh ? sumHigh / nHigh : double.nan;
    s.avgLow = nLow ? sumLow / nLow : double.nan;

    // 周期：相邻上升沿间距的均值（需 >= 2 个上升沿）
    Edge[] rising = findRisingEdges(w);
    if (rising.length >= 2)
    {
        double periodSum = 0;
        foreach (i; 1 .. rising.length)
            periodSum += w.countToDuration(rising[i].index - rising[i - 1].index);
        s.period = periodSum / cast(double)(rising.length - 1);
        s.frequency = s.period > 0 ? 1.0 / s.period : double.nan;
        if (s.period > 0 && nHigh > 0)
            s.dutyCycle = s.avgHigh / s.period;
    }
    return s;
}

@safe unittest
{
    import std.math : isNaN;

    static bool approx(double a, double b, double eps = 1e-9)
    {
        return (a - b) > -eps && (a - b) < eps;
    }

    // 周期方波：高 3 采样、低 1 采样、周期 4
    bool[] s = [true, true, true, false,
                true, true, true, false,
                true, true, true, false];
    auto w = Waveform(s, 1000);
    auto t = analyzeTiming(w);
    assert(approx(t.avgHigh, 0.003));
    assert(approx(t.avgLow, 0.001));
    assert(approx(t.period, 0.004));
    assert(approx(t.frequency, 250.0));
    assert(t.dutyCycle > 0.7499 && t.dutyCycle < 0.7501);

    // 非周期：仅 1 个上升沿
    bool[] s2 = [false, true, false];
    auto t2 = analyzeTiming(Waveform(s2, 1000));
    assert(isNaN(t2.period));
    assert(isNaN(t2.frequency));
    assert(isNaN(t2.dutyCycle));
    assert(approx(t2.avgHigh, 0.001));

    // 空波形
    bool[] empty;
    auto t3 = analyzeTiming(Waveform(empty, 0));
    assert(isNaN(t3.avgHigh));
}
