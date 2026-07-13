module dlogicanalyzer.edges;

import dlogicanalyzer.waveform;

/// 边沿类型。
enum EdgeType { rising, falling }

/// 一个跳变边沿：type 为方向，index 为发生跳变的采样点索引（跳变后那一帧）。
struct Edge
{
    EdgeType type;
    ulong index;
}

/// 找出波形中所有上升沿与下降沿。
Edge[] findEdges(Waveform w) @safe pure
{
    Edge[] result;
    if (w.samples.length < 2)
        return result;
    for (ulong i = 1; i < w.samples.length; i++)
    {
        const prev = w.samples[i - 1];
        const cur = w.samples[i];
        if (!prev && cur)
            result ~= Edge(EdgeType.rising, i);
        else if (prev && !cur)
            result ~= Edge(EdgeType.falling, i);
    }
    return result;
}

/// 仅找出上升沿。
Edge[] findRisingEdges(Waveform w) @safe pure
{
    Edge[] result;
    if (w.samples.length < 2)
        return result;
    for (ulong i = 1; i < w.samples.length; i++)
    {
        if (!w.samples[i - 1] && w.samples[i])
            result ~= Edge(EdgeType.rising, i);
    }
    return result;
}

/// 仅找出下降沿。
Edge[] findFallingEdges(Waveform w) @safe pure
{
    Edge[] result;
    if (w.samples.length < 2)
        return result;
    for (ulong i = 1; i < w.samples.length; i++)
    {
        if (w.samples[i - 1] && !w.samples[i])
            result ~= Edge(EdgeType.falling, i);
    }
    return result;
}

@safe unittest
{
    bool[] s = [false, false, true, true, false, true, false];
    auto w = Waveform(s, 0);

    auto e = findEdges(w);
    assert(e.length == 4);
    assert(e[0].type == EdgeType.rising && e[0].index == 2);
    assert(e[1].type == EdgeType.falling && e[1].index == 4);
    assert(e[2].type == EdgeType.rising && e[2].index == 5);
    assert(e[3].type == EdgeType.falling && e[3].index == 6);

    assert(findRisingEdges(w).length == 2);
    assert(findFallingEdges(w).length == 2);

    bool[] empty;
    assert(findEdges(Waveform(empty, 0)).length == 0);
    assert(findEdges(Waveform([true], 0)).length == 0);
    assert(findEdges(Waveform([true, true, true], 0)).length == 0);
}
