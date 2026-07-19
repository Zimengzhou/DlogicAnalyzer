module dlogicanalyzer.timing;

import dlogicanalyzer.waveform;
import dlogicanalyzer.levels;

/// 周期性/一般波形的时序统计。
struct TimingStats
{
    double period;       /// 周期（秒）；非周期信号为 NaN
    double frequency;    /// 频率（Hz）；非周期信号为 NaN
    double dutyCycle;    /// 占空比 0..1；非周期信号为 NaN
    double avgHigh;      /// 平均高电平持续时间（秒）
    double avgLow;       /// 平均低电平持续时间（秒）
}

/// 由游程编码推导时序统计（上升沿从 Level 段之间推导，无需额外遍历）。
/// 一次 O(n) 遍历同时完成：①统计高/低电平总时长  ②记录上升沿位置用于计算周期。
TimingStats analyzeTiming(const Waveform w) @safe pure
{
    TimingStats s;
    // 所有字段初始化为 NaN，后续只在有足够数据时覆盖
    s.period = double.nan;
    s.frequency = double.nan;
    s.dutyCycle = double.nan;
    s.avgHigh = double.nan;
    s.avgLow = double.nan;

    // 先对波形进行游程编码，得到连续电平段
    Level[] segs = runs(w);
    if (segs.length == 0)
        return s;

    double sumHigh = 0, sumLow = 0;  // 高/低电平总时长
    ulong nHigh = 0, nLow = 0;       // 高/低电平段数量
    ulong[] risingIndices;            // 记录所有上升沿的采样点索引

    // 一次遍历：统计电平时长 + 提取上升沿位置
    foreach (i, seg; segs)
    {
        // 累加各电平段时长
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

        // 低→高段切换处即为一个上升沿，记录其起始索引
        if (i > 0 && !segs[i - 1].high && seg.high)
            risingIndices ~= seg.start;
    }

    // 计算平均高/低电平时长
    s.avgHigh = nHigh ? sumHigh / nHigh : double.nan;
    s.avgLow = nLow ? sumLow / nLow : double.nan;

    // 至少需要 2 个上升沿才能计算周期
    if (risingIndices.length >= 2)
    {
        double periodSum = 0;
        // 相邻上升沿间距求和
        foreach (i; 1 .. risingIndices.length)
            periodSum += w.countToDuration(risingIndices[i] - risingIndices[i - 1]);
        // 周期 = 上升沿间距的均值
        s.period = periodSum / cast(double)(risingIndices.length - 1);
        // 频率 = 1 / 周期
        s.frequency = s.period > 0 ? 1.0 / s.period : double.nan;
        // 占空比 = 平均高电平时间 / 周期
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
