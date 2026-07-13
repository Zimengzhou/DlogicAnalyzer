import std.stdio;
import dlogicanalyzer.waveform;
import dlogicanalyzer.edges;
import dlogicanalyzer.levels;
import dlogicanalyzer.timing;

version (Windows)
    import core.sys.windows.windows;

void main()
{
    version (Windows)
        SetConsoleOutputCP(65_001);

    // 示例波形：近似周期性方波
    bool[] samples = [0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0, 0];
    Waveform w = Waveform(samples, 1000); // 1 kHz 采样

    // 波形预览
    writefln("波形 (%d 采样点, 采样率 %d Hz):", w.length, w.sampleRate);
    foreach (s; w.samples)
        write(s ? '1' : '0');
    writeln("\n");

    // 边沿
    auto edges = findEdges(w);
    writefln("边沿 (%d 个):", edges.length);
    foreach (e; edges)
        writefln("  %s @ 采样点 %d", e.type == EdgeType.rising ? "↑ 上升" : "↓ 下降", e.index);
    writeln;

    // 高低电平段
    auto segs = runs(w);
    writefln("电平段 (%d 段):", segs.length);
    foreach (seg; segs)
        writefln("  %s [%d..%d)  计数=%d  时长=%.3f s",
                 seg.high ? "高" : "低", seg.start, seg.end, seg.count, seg.duration);
    writeln;

    // 时序统计
    auto t = analyzeTiming(w);
    writeln("时序统计:");
    writefln("  平均高电平时长 = %.3f s", t.avgHigh);
    writefln("  平均低电平时长 = %.3f s", t.avgLow);
    writefln("  周期           = %.3f s", t.period);
    writefln("  频率           = %.3f Hz", t.frequency);
    writefln("  占空比         = %.2f%%", t.dutyCycle * 100.0);
}
