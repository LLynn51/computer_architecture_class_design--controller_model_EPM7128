 | 名称 | 助记符 | 功能 | 指令格式 IR7 IR6 IR5 IR4 | IR3 IR2 | IR1 IR0 |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 加法 | ADD Rd, Rs | Rd ← Rd + Rs | 0001 | Rd | Rs |
| 减法 | SUB Rd, Rs | Rd ← Rd - Rs | 0010 | Rd | Rs |
| 逻辑与 | AND Rd, Rs | Rd ← Rd and Rs | 0011 | Rd | Rs |
| 加1 | INC Rd | Rd ← Rd + 1 | 0100 | Rd | XX |
| 取数 | LD Rd, [Rs] | Rd ← [Rs] | 0101 | Rd | Rs |
| 存数 | ST Rs, [Rd] | Rs → [Rd] | 0110 | Rd | Rs |
| C条件转移 | JC addr | 如果 C=1，则 PC ← @ + offset | 0111 | offset | |
| Z条件转移 | JZ addr | 如果 Z=1，则 PC ← @ + offset | 1000 | offset | |
| 无条件转移 | JMP [Rd] | PC ← Rd | 1001 | Rd | XX |
| 输出 | OUT Rs | DBUS ← Rs | 1010 | XX | Rs |
| 中断返回 | IRET | 返回断点 | 1011 | XX | XX |
| 关中断 | DI | 禁止中断 | 1100 | XX | XX |
| 开中断 | EI | 允许中断 | 1101 | XX | XX |
| 停机 | STP | 暂停运行 | 1110 | XX | XX |