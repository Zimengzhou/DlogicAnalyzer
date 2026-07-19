module dlogicanalyzer.levels;

import dlogicanalyzer.waveform;

/// 一段连续相同电平的游程（Run-Length Encoding 的结果）。
struct Level
{
    bool high;        /// true=高电平, false=低电平
    ulong start;      /// 起始采样点（含）
    ulong end;        /// 结束采样点（不含），区间为 [start, end)
    double duration;  /// 持续时间（秒）；sampleRate=0 时为采样点数

    /// 持续采样点数 = end - start（计算属性，避免数据冗余）。
    @property ulong count() const @safe @nogc pure
    {
        return end - start;
    }
}

/// 游程编码：遍历波形，将连续相同电平合并为一段 Level。
Level[] runs(const Waveform w) @safe pure
{
    Level[] result;
    // 空波形没有电平段
    if (w.samples.length == 0)
        return result;

    ulong start = 0;        // 当前段的起始索引
    bool cur = w.samples[0]; // 当前段的电平值
    // 从第二个点开始扫描，遇到电平变化时切分一段
    for (ulong i = 1; i < w.samples.length; i++)
    {
        if (w.samples[i] != cur)
        {
            // 电平翻转，记录上一段并开始新段
            result ~= Level(cur, start, i, w.countToDuration(i - start));
            start = i;
            cur = w.samples[i];
        }
    }
    // 处理最后一段到波形末尾
    result ~= Level(cur, start, w.samples.length,
                    w.countToDuration(w.samples.length - start));
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
