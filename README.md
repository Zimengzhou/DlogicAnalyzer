# DlogicAnalyzer — 项目框架说明

## 1. 项目简介

**DlogicAnalyzer** 是一个使用 D 语言编写的**数字信号分析库**，用于对二进制（0/1）采样波形进行边沿检测、游程编码和时序统计分析。

- **包名**: `dlogicanalyzer`
- **作者**: SZM
- **许可证**: GPL-3.0-or-later
- **构建系统**: [Dub](https://code.dlang.org/)
- **外部依赖**: 无（仅依赖 D 标准库 Phobos + DRuntime）

---

## 2. 目录结构

```
DlogicAnalyzer/
├── .gitignore
├── .dub/
│   └── version.json              # Dub 版本跟踪
├── dub.json                      # 包清单（构建配置）
├── docs/
│   └── ARCHITECTURE.md           # 本文件
└── source/
    ├── app.d                     # 入口 / 演示程序
    └── dlogicanalyzer/           # 库模块命名空间
        ├── waveform.d            # 核心数据结构：Waveform
        ├── edges.d               # 边沿检测（上升/下降沿）
        ├── levels.d              # 游程编码（高/低电平段）
        └── timing.d              # 时序统计（周期、频率、占空比）
```

---

## 3. 模块依赖关系

```
                         ┌──────────────┐
                         │   app.d      │  (演示入口)
                         └──┬───┬───┬───┘
                            │   │   │
            ┌───────────────┼┐  │   │
            │     ┌─────────┼┼──┘   │
            │     │  ┌──────┼┼──────┘
            ▼     ▼  ▼      ▼▼
    ┌──────────┐ ┌──────────┐ ┌──────────┐
    │ edges.d  │ │ levels.d │ │ timing.d │  (分析层)
    └────┬─────┘ └────┬─────┘ └────┬─────┘
         │            │            │
         └──────┬─────┘            │
                ▼                  │
         ┌──────────────┐          │
         │ waveform.d   │◄─────────┘  (数据层)
         └──────────────┘
```

- `waveform.d` — 叶子节点，无模块内依赖
- `edges.d` — 依赖 `waveform.d`
- `levels.d` — 依赖 `waveform.d`
- `timing.d` — 依赖 `waveform.d` + `edges.d` + `levels.d`
- `app.d` — 依赖所有库模块

---

## 4. 核心模块说明

### 4.1 `dlogicanalyzer.waveform` — 数据模型

**文件**: `source/dlogicanalyzer/waveform.d`

定义核心数据结构 `Waveform`，作为所有分析函数的统一输入格式：

```d
struct Waveform
{
    bool[] samples;    // 0/1 采样序列
    ulong sampleRate;  // 采样率（Hz）；为 0 时 duration 退化为采样点数

    double countToDuration(ulong count) const;  // 采样点数 → 秒
    @property ulong length() const;             // 采样点总数
}
```

---

### 4.2 `dlogicanalyzer.edges` — 边沿检测

**文件**: `source/dlogicanalyzer/edges.d`

检测波形中信号的跳变点：

| 导出符号 | 类型 | 说明 |
|----------|------|------|
| `EdgeType` | `enum` | `rising` (0→1), `falling` (1→0) |
| `Edge` | `struct` | `EdgeType type` + `ulong index`（跳变后采样点索引） |
| `findEdges(Waveform)` | 函数 → `Edge[]` | 找出所有上升沿与下降沿 |
| `findRisingEdges(Waveform)` | 函数 → `Edge[]` | 仅找出上升沿 |
| `findFallingEdges(Waveform)` | 函数 → `Edge[]` | 仅找出下降沿 |

- `index` 为**跳变发生后的第一个采样点**的索引（即 `w.samples[i]` 处，其中 `w.samples[i-1] != w.samples[i]`）
- 对空波形（`length < 2`）或恒定信号，返回空数组
- 所有函数标记为 `@safe pure`

---

### 4.3 `dlogicanalyzer.levels` — 游程编码

**文件**: `source/dlogicanalyzer/levels.d`

将波形拆分为连续的高/低电平段（Run-Length Encoding）：

| 导出符号 | 类型 | 说明 |
|----------|------|------|
| `Level` | `struct` | `bool high`, `ulong start`, `ulong end`, `ulong count`, `double duration` |
| `runs(Waveform)` | 函数 → `Level[]` | 返回所有连续电平段 |

- 区间为 **`[start, end)`** 半开区间
- `duration` 以秒为单位（`sampleRate` 为 0 时退化为采样点数）
- 空波形返回空数组；恒定信号返回一段

---

### 4.4 `dlogicanalyzer.timing` — 时序统计

**文件**: `source/dlogicanalyzer/timing.d`

基于游程编码与边沿检测，产出聚合统计数据：

| 导出符号 | 类型 | 说明 |
|----------|------|------|
| `TimingStats` | `struct` | `period`, `frequency`, `dutyCycle`, `avgHigh`, `avgLow` (均为 `double`) |
| `analyzeTiming(Waveform)` | 函数 → `TimingStats` | 计算全部时序统计量 |

**计算规则**：

| 字段 | 计算方式 |
|------|----------|
| `avgHigh` | 所有高电平段 `duration` 的均值 |
| `avgLow` | 所有低电平段 `duration` 的均值 |
| `period` | 相邻上升沿间距的均值（需 ≥2 个上升沿） |
| `frequency` | `1.0 / period` |
| `dutyCycle` | `avgHigh / period` |

- 若上升沿不足 2 个（非周期信号），`period` / `frequency` / `dutyCycle` 返回 `NaN`
- 若不存在高/低电平段，对应字段返回 `NaN`

---

### 4.5 `app.d` — 入口 / 演示程序

**文件**: `source/app.d`

`void main()` 函数，用于演示库功能。流程：

1. 设置 Windows 控制台输出代码页为 UTF-8（`SetConsoleOutputCP(65001)`）
2. 构建硬编码示例波形（约 27 个采样点，1 kHz 采样率）
3. 依次输出：波形概览 → 边沿列表 → 电平段列表 → 时序统计

---

## 5. 构建与运行

### 编译

```bash
# 编译库 + 可执行文件
dub build

# 运行测试
dub test

# 运行演示程序
dub run
```

`dub.json` 中不含第三方依赖，开箱即用。

---

## 6. 数据处理流程

```
bool[] 采样数据  ───────────────────────────────────────────────────┐
     │                                                               │
     ▼                                                               │
┌──────────┐                                                         │
│ Waveform │  (封装 samples + sampleRate)                            │
└────┬─────┘                                                         │
     │                                                               │
     ├──────────────────────┬────────────────────────┐               │
     ▼                      ▼                        ▼               │
┌──────────┐         ┌──────────────┐        ┌──────────────┐       │
│ findEdges│         │    runs()    │        │analyzeTiming()│       │
│  → Edge[] │         │   → Level[]   │        │ → TimingStats │       │
└────┬─────┘         └──────┬───────┘        └──────┬───────┘       │
     │                      │                       │               │
     ▼                      ▼                       ▼               │
  边沿列表               高/低电平段               统计值             │
 (时间/方向)           (起止/长度/时长)     (周期/频率/占空比/...)    │
```

数据流是**单向管道**：原始采样 → `Waveform` → 各分析函数 → 结构化结果。

---

## 7. 代码质量特征

- 所有库函数标记 `@safe`，编译期保证内存安全
- 纯函数（`pure`）标注，无副作用，适合并行分析
- 每个模块包含 `@safe unittest` 块，覆盖空输入、边界条件、正常场景
- 无外部依赖，编译快速（仅依赖 D 标准库）

---

## 8. API 快速参考

```d
import dlogicanalyzer.waveform;
import dlogicanalyzer.edges;
import dlogicanalyzer.levels;
import dlogicanalyzer.timing;

// 构建波形
auto w = Waveform([0, 1, 1, 0, 0, 1, 0], 1000);

// 边沿检测
Edge[] edges = findEdges(w);             // 全部边沿
Edge[] rising = findRisingEdges(w);      // 仅上升沿
Edge[] falling = findFallingEdges(w);    // 仅下降沿

// 游程编码
Level[] segments = runs(w);

// 时序统计
TimingStats stats = analyzeTiming(w);
// stats.period, stats.frequency, stats.dutyCycle, stats.avgHigh, stats.avgLow
```
