module dlogicanalyzer.levels;

import dlogicanalyzer.waveform;

/// 一段连续相同电平的游程。
struct Level
{
    bool high;        /// true=高电平, false=低电平
    ulong start;      /// 起始采样点（含）
    ulong end;        /// 结束采样点（不含），区间为 [start, end)
    ulong count;      /// 持续采样点数 = end - start
    double duration;  /// 持续时间（秒）；sampleRate=0 时为采样点数
}

/// 游程编码：把波形拆成连续的高/低电平段。
Level[] runs(Waveform w) @safe pure
{
    Level[] result;
    if (w.samples.length == 0)
        return result;

    ulong start = 0;
    bool cur = w.samples[0];
    for (ulong i = 1; i < w.samples.length; i++)
    {
        if (w.samples[i] != cur)
        {
            result ~= Level(cur, start, i, i - start, w.countToDuration(i - start));
            start = i;
            cur = w.samples[i];
        }
    }
    result ~= Level(cur, start, w.samples.length,
                    w.samples.length - start, w.countToDuration(w.samples.length - start));
    return result;
}

@safe unittest
{
    bool[] s = [false, false, true, true, true, false];
    auto w = Waveform(s, 1000);
    auto r = runs(w);
    assert(r.length == 3);
    assert(r[0].high == false && r[0].start == 0 && r[0].end == 2 &&
           r[0].count == 2 && r[0].duration == 0.002);
    assert(r[1].high == true && r[1].start == 2 && r[1].end == 5 &&
           r[1].count == 3 && r[1].duration == 0.003);
    assert(r[2].high == false && r[2].start == 5 && r[2].end == 6 &&
           r[2].count == 1 && r[2].duration == 0.001);

    bool[] empty;
    assert(runs(Waveform(empty, 0)).length == 0);

    auto single = runs(Waveform([true], 0));
    assert(single.length == 1);
    assert(single[0].high == true && single[0].count == 1);
}
