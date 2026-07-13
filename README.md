# DlogicAnalyzer — 项目框架说明

## 1. 项目简介

**DlogicAnalyzer** 是一个使用 D 语言作为后端的**逻辑分析仪**，用于对二进制（0/1）采样波形进行边沿检测、编码和时序分析。

- **包名**: `dlogicanalyzer`
- **作者**: SZM,DeepSeek,GLM (大部分使用AI生成)
- **许可证**: GPL-3.0-or-later
- **构建系统**: [Dub](https://code.dlang.org/)
- **外部依赖**: 无（仅依赖 D 标准库 Phobos + DRuntime）
-- **本说明也由AI生成的，花了几毛钱**

---

## 2. 目录结构

```
DlogicAnalyzer/
├── .gitignore
├── .dub/
│   └── version.json              # Dub 版本跟踪
├── dub.json                      # 包清单（构建配置）
├── docs/
│   └── ARCHITECTURE.md           # 详细架构文档
└── source/
    ├── app.d                     # 入口 / 演示程序
    └── dlogicanalyzer/           # 应用模块命名空间
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
                         └──┬───┬───┬──┘
                            │   │   │
            ┌───────────────┼┐  │   │
            │               ││  │   │
            ▼               ▼▼  ▼   │
    ┌──────────┐      ┌──────────┐  │
    │ edges.d  │      │ levels.d │  │  (分析层)
    └────┬─────┘      └────┬─────┘  │
         │                  │        │
         └──────┬───────────┘        │
                ▼                    │
         ┌──────────────┐            │
         │ waveform.d   │◄───────────┘  (数据层)
         └──────────────┘
              ▲
              │
    ┌─────────┴──────┐
    │   timing.d     │  (统计层)
    └────────────────┘
```

- `waveform.d` — 叶子节点，无模块内依赖
- `edges.d` — 依赖 `waveform.d`
- `levels.d` — 依赖 `waveform.d`
- `timing.d` — 依赖 `waveform.d` + `levels.d`（上升沿从游程结果推导，无需再依赖 `edges.d`）
- `app.d` — 依赖所有模块

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
    @property size_t length() const;            // 采样点总数
    @property double totalDuration() const;     // 波形总时长（秒）
}
```

---

### 4.2 `dlogicanalyzer.edges` — 边沿检测

**文件**: `source/dlogicanalyzer/edges.d`

检测波形中信号的跳变点。三个公共函数共享同一个编译期模板实现 (`findEdgesImpl`)，通过 `static if` 在编译期消除死代码：

| 导出符号 | 类型 | 说明 |
|----------|------|------|
| `EdgeType` | `enum` | `rising` (0→1), `falling` (1→0) |
| `Edge` | `struct` | `EdgeType type` + `ulong index`（跳变后采样点索引） |
| `findEdges(Waveform)` | 函数 → `Edge[]` | 找出所有上升沿与下降沿 |
| `findRisingEdges(Waveform)` | 函数 → `Edge[]` | 仅找出上升沿 |
| `findFallingEdges(Waveform)` | 函数 → `Edge[]` | 仅找出下降沿 |

- `index` 为**跳变发生后的第一个采样点**的索引
- 参数为 `const Waveform`，明确只读语义
- 对空波形（`length < 2`）或恒定信号，返回空数组

---

### 4.3 `dlogicanalyzer.levels` — 游程编码

**文件**: `source/dlogicanalyzer/levels.d`

将波形拆分为连续的高/低电平段（Run-Length Encoding）：

| 导出符号 | 类型 | 说明 |
|----------|------|------|
| `Level` | `struct` | `bool high`, `ulong start`, `ulong end`, `double duration`；`count` 为 `@property`（= `end - start`） |
| `runs(Waveform)` | 函数 → `Level[]` | 返回所有连续电平段 |

- 区间为 **`[start, end)`** 半开区间
- `count` 为计算属性，避免数据冗余
- `duration` 以秒为单位（`sampleRate` 为 0 时退化为采样点数）
- 参数为 `const Waveform`

---

### 4.4 `dlogicanalyzer.timing` — 时序统计

**文件**: `source/dlogicanalyzer/timing.d`

基于游程编码一次遍历产出全部统计数据。上升沿从游程结果直接推导（相邻低→高段），无需调用 `edges` 模块：

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
- 参数为 `const Waveform`

---

### 4.5 `app.d` — 入口 / 演示程序

**文件**: `source/app.d`

`void main()` 函数，用于演示功能。Windows API 调用使用 `version(Windows)` 条件编译。流程：

1. 构建硬编码示例波形（约 27 个采样点，1 kHz 采样率）
2. 依次输出：波形概览 → 边沿列表 → 电平段列表 → 时序统计

---

## 5. 构建与运行

### 编译

```bash
# 编译可执行文件
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
│ Waveform │  (封装 samples + sampleRate + totalDuration)            │
└────┬─────┘                                                         │
     │                                                               │
     ├──────────────────┬────────────────────────┐                  │
     ▼                  ▼                        ▼                  │
┌──────────┐     ┌──────────────┐        ┌──────────────┐          │
│ findEdges│     │    runs()    │        │analyzeTiming()│          │
│  → Edge[] │     │   → Level[]   │        │ → TimingStats │          │
└────┬─────┘     └──────┬───────┘        └──────┬───────┘          │
     │                  │                       │                  │
     ▼                  ▼                       ▼                  │
  边沿列表           高/低电平段               统计值                │
 (方向/索引)       (起止/计数/时长)     (周期/频率/占空比/...)       │
                                                                     │
  ※ analyzeTiming 内部复用 runs() 结果推导上升沿，仅一次 O(n) 遍历  │
```

---

## 7. 代码质量特征

- 所有分析函数标记 `@safe pure`，编译期保证内存安全、无副作用
- 函数参数使用 `const`，明确只读语义
- 每个模块包含 `@safe unittest` 块，覆盖空输入、边界条件、正常场景
- `edges.d` 使用编译期模板 + `static if` 消除三函数间的重复代码
- `timing.d` 在单次遍历中同时计算游程与上升沿，避免二次遍历
- `Level.count` 为计算属性（`@property`），消除数据冗余
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

// 基础属性
size_t n = w.length;
double t = w.totalDuration;     // 总时长（秒）

// 边沿检测
Edge[] edges = findEdges(w);             // 全部边沿
Edge[] rising = findRisingEdges(w);      // 仅上升沿
Edge[] falling = findFallingEdges(w);    // 仅下降沿

// 游程编码
Level[] segments = runs(w);
// segments[0].high, .start, .end, .count, .duration

// 时序统计
TimingStats stats = analyzeTiming(w);
// stats.period, stats.frequency, stats.dutyCycle, stats.avgHigh, stats.avgLow
```
