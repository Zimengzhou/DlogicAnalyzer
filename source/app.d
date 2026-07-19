import std.stdio;
import dlogicanalyzer.waveform;
import dlogicanalyzer.edges;
import dlogicanalyzer.levels;
import dlogicanalyzer.timing;

// Windows 平台下需要设置控制台 UTF-8 编码以正确显示中文
version (Windows)
    import core.sys.windows.windows;

void main()
{
    // 将 Windows 控制台代码页设为 UTF-8，确保中文输出不乱码
    version (Windows)
        SetConsoleOutputCP(65_001);

    // 示例波形：近似周期性方波，包含多种脉冲宽度变化
    bool[] samples = [0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 0,0, 0, 1, 1, 1, 0,0,0,0,0,1,1,1,1,0,0,0,0, 1, 1, 1, 0, 1, 1, 1, 0,];
    // 采样率 1000 Hz，即每个采样点代表 1 ms
    Waveform w = Waveform(samples, 1000);

    // 用 ASCII 字符打印波形概览（'1' 高电平，'0' 低电平）
    writefln("波形 (%d 采样点, 采样率 %d Hz):", w.length, w.sampleRate);
    foreach (s; w.samples)
        write(s ? '1' : '0');
    writeln("\n");

    // 输出边沿检测结果：每个跳变的位置和方向
    auto edges = findEdges(w);
    writefln("边沿 (%d 个):", edges.length);
    foreach (e; edges)
        writefln("  %s @ 采样点 %d", e.type == EdgeType.rising ? "↑ 上升" : "↓ 下降", e.index);
    writeln;

    // 输出游程编码结果：连续高/低电平段的起止、计数和时长
    auto segs = runs(w);
    writefln("电平段 (%d 段):", segs.length);
    foreach (seg; segs)
        writefln("  %s [%d..%d)  计数=%d  时长=%.3f s",
                 seg.high ? "高" : "低", seg.start, seg.end, seg.count, seg.duration);
    writeln;

    // 输出时序统计分析结果
    auto t = analyzeTiming(w);
    writeln("时序统计:");
    writefln("  平均高电平时长 = %.3f s", t.avgHigh);
    writefln("  平均低电平时长 = %.3f s", t.avgLow);
    writefln("  周期           = %.3f s", t.period);
    writefln("  频率           = %.3f Hz", t.frequency);
    writefln("  占空比         = %.2f%%", t.dutyCycle * 100.0);
}
