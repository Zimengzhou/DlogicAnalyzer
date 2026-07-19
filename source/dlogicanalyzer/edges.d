module dlogicanalyzer.edges;

import dlogicanalyzer.waveform;

/// 边沿类型。
enum EdgeType { rising, falling }

/// 一个跳变边沿：type 为方向，index 为发生跳变后的采样点索引。
struct Edge
{
    EdgeType type;
    ulong index;
}

/// 边沿检测的编译期模板实现。
/// 通过两个布尔模板参数控制是否检测上升沿/下降沿，编译期消除无用分支。
private Edge[] findEdgesImpl(bool detectRising, bool detectFalling)(const Waveform w) @safe pure
{
    Edge[] result;
    // 不足 2 个采样点无法检测跳变，直接返回空数组
    if (w.samples.length < 2)
        return result;
    // 从第二个采样点开始，逐个与前一个比较
    for (ulong i = 1; i < w.samples.length; i++)
    {
        static if (detectRising)
        {
            // 前一个为低、当前为高 → 上升沿
            if (!w.samples[i - 1] && w.samples[i])
                result ~= Edge(EdgeType.rising, i);
        }
        static if (detectFalling)
        {
            // 前一个为高、当前为低 → 下降沿
            if (w.samples[i - 1] && !w.samples[i])
                result ~= Edge(EdgeType.falling, i);
        }
    }
    return result;
}

/// 找出波形中所有上升沿与下降沿（开启两种边沿检测）。
Edge[] findEdges(const Waveform w) @safe pure
{
    return findEdgesImpl!(true, true)(w);
}

/// 仅找出上升沿（只检测 0→1 跳变）。
Edge[] findRisingEdges(const Waveform w) @safe pure
{
    return findEdgesImpl!(true, false)(w);
}

/// 仅找出下降沿（只检测 1→0 跳变）。
Edge[] findFallingEdges(const Waveform w) @safe pure
{
    return findEdgesImpl!(false, true)(w);
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
