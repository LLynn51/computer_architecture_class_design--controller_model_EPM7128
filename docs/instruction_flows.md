 这张图是一个**TEC-8/TEC-PLUS 硬布线控制器流程图**，包含复杂的分支结构和控制信号，无法直接转化为单一的 Markdown 表格。我可以将其转化为结构化的 **Markdown 文本描述**，按流程层级整理：

---

## TEC-8/TEC-PLUS 硬布线控制器流程图

### 顶层：CLR 复位

```
CLR
  └── SWC SWB SWA 判断
```

| SWC SWB SWA | 操作 | 说明 |
|:---:|:---|:---|
| 100 | 写寄存器 | STO=0 / STO=1 分支 |
| 011 | 读寄存器 | |
| 000 | 取指 | |
| 010 | 读存储器 | STO=0 / STO=1 分支 |
| 001 | 写存储器 | STO=0 / STO=1 分支 |

---

### 一、写寄存器 (SWC SWB SWA = 100)

#### W1 周期

| STO | 控制信号 |
|:---:|:---|
| 0 | SBUS, SEL3=0, SEL2=0, SEL1=1, SEL0=1, SELCTL, DRW, STOP |
| 1 | SBUS, SEL3=1, SEL2=0, SEL1=0, SEL0=1, SELCTL, DRW, STOP |

#### W2 周期

| STO | 控制信号 |
|:---:|:---|
| 0 | SBUS, SEL3=0, SEL2=1, SEL1=0, SEL0=0, SELCTL, STOP, DRW, SSTO |
| 1 | SBUS, SEL3=1, SEL2=1, SEL1=1, SEL0=0, SELCTL, DRW, STOP |

---

### 二、读寄存器 (SWC SWB SWA = 011)

#### W1 周期

| 控制信号 |
|:---|
| SEL3=0, SEL1=0, SEL1=0, SEL0=1, SELCTL, STOP |

#### W2 周期

| 控制信号 |
|:---|
| SEL3=1, SEL2=0, SEL1=1, SEL0=1, SELCTL, STOP |

---

### 三、读存储器 (SWC SWB SWA = 010)

#### W1 周期

| STO | 控制信号 |
|:---:|:---|
| 0 | SBUS, LAR, STOP, SSTO, SHORT, SELCTL |
| 1 | MBUS, ARINC, STOP, SHORT, SELCTL |

#### W2 周期

| STO | 控制信号 |
|:---:|:---|
| 0 | SBUS, LAR, STOP, SSTO, SHORT, SELCTL |
| 1 | SBUS, MEMW, ARINC, STOP, SHORT, SELCTL |

---

### 四、写存储器 (SWC SWB SWA = 001)

#### W1 周期

| STO | 控制信号 |
|:---:|:---|
| 0 | SBUS, LAR, STOP, SSTO, SHORT, SELCTL |
| 1 | SBUS, MEMW, ARINC, STOP, SHORT, SELCTL |

---

### 五、取指 (SWC SWB SWA = 000)

#### W1 周期

| 控制信号 |
|:---|
| LIR, PCINC |

#### W2 周期 → IR7~IR4 指令译码

| IR7~IR4 | 指令 | 控制信号 (W2) |
|:---:|:---:|:---|
| 0001 | ADD | S=1001, CIN, ABUS, DRW, LDZ, LDC |
| 0010 | SUB | S=0110, ABUS, DRW, LDZ, LDC |
| 0011 | AND | M, S=1011, ABUS, DRW, LDZ |
| 0100 | INC | S=0000, ABUS, DRW, LDZ, LDC |
| 0101 | LD | M, S=1010, ABUS, LAR, LONG |
| 0110 | ST | M, S=1111, ABUS, LAR, LONG |
| 0111 | JC | C=0: (空); C=1: PCADD |
| 1000 | JZ | Z=0: (空); Z=1: PCADD |
| 1001 | JMP | M, S=1111, ABUS, LPC |
| 1110 | STP | STOP |

#### W3 周期 (LD/ST 指令)

| 指令 | 控制信号 (W3) |
|:---:|:---|
| LD | DRW, MBUS |
| ST | S=1010, M, ABUS, MEMW |

---

> **注**：图中部分控制信号框（如 JC 的 C=0 分支、JZ 的 Z=0 分支）为空白/省略，表示该条件下无额外控制信号输出，流程直接结束或进入下一周期。