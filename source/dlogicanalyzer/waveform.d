module dlogicanalyzer.waveform;

/// 单通道采样波形：每个采样点为 0/1（false/true）。
struct Waveform
{
    bool[] samples;    /// 0/1 采样序列
    ulong sampleRate;  /// 采样率（Hz）；为 0 时 duration 退化为采样点数

    /// 将采样点数换算为时间（秒）；sampleRate 为 0 时直接返回 count。
    double countToDuration(ulong count) const @safe @nogc pure
    {
        if (sampleRate == 0)
            return cast(double) count;
        return cast(double) count / cast(double) sampleRate;
    }

    /// 采样点总数。
    @property ulong length() const @safe @nogc pure
    {
        return samples.length;
    }
}

@safe unittest
{
    bool[] s = [true, false, true];
    auto w = Waveform(s, 1000);
    assert(w.countToDuration(500) == 0.5);
    assert(w.length == 3);

    auto w0 = Waveform(s, 0);
    assert(w0.countToDuration(5) == 5.0, "w0.countToDuration(5) should be 5");
}
