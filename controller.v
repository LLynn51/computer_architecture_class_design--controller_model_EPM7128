module controller (
    input CLR,  // 全局复位
    input T3,  // 下降沿有效，全局唯一外界时钟信号
    // 从平台读指令
    input [2:0] SW,  //SWC SWB SWA
    input [3:0] IR,  // IR7~4

    input C,Z,

    // PC
    // 其中PCINC用于PC自增，PCADD用于加偏移
    output reg LPC,PCINC,PCADD,

    // AR
    output reg LAR,ARINC,
    // IR
    output reg LIR,
    // C/Z标志位相关
    output reg LDZ,LDC,
    // ALU相关
    output reg [3:0] S,  // ALU功能选择
    output reg M,  // (M=1:逻辑运算；M=0:算术运算)
    output reg CIN,  // 进位
    // 总线与访存
    output reg MEMW,ABUS,SBUS,MBUS,
    // MUX多路选择器 
    output reg [3:0] SEL,  // 寄存器选择，注意与S区分
    output reg SELCTL,  // MUX使能
    output reg DRW,
    output reg SHORT,LONG,STOP
);
  localparam WREG = 3'b100, RREG = 3'b011, FETCH = 3'b000, RMEM = 3'b010, WMEM = 3'b001;
  localparam ADD = 4'b0001, SUB = 4'b0010, AND = 4'b0011,INC = 4'b0100, LD = 4'b0101, ST = 4'b0110, 
	           STP = 4'b1110,JC = 4'b0111, JZ = 4'b1000, JMP = 4'b1001;
  reg STO;
  localparam W0 = 3'b000, W1 = 3'b001, W2 = 3'b010, W3 = 3'b100;
  // 时序阶段W1~W3,W0定义为刚刚开机需要一次自动复位
  reg [2:0] W;

  // 下面是phase2新增关键变量=============================================
  // phase2：新增三级流水：IF（固定）、EX（固定）、MEM（特殊访存指令专属）
  reg [3:0] EX_IR;  // 锁存正在EX阶段的指令
  reg IF_valid; // 当前IF阶段是否有一条可以推进到EX阶段的指令？如果有，置1；
  reg EX_valid;  // 当前EX_IR中是否有一条可以执行的有效指令？如果有，置1；
  reg halted; // 用于标识停机指令的状态；
  reg stall;  // 标识当前是否在冒险
  // 当前最小闭环仅实现算数/逻辑指令的流水（仅使用W1），会有两拍填充延迟。即每次CLR后：
  /*
        cycle1: 取 I1，不执行
        cycle2: 锁存 I1，不执行
        cycle3: 执行 I1，同时取/锁存后续指令
    */


  // 控制器主体逻辑
  always @(negedge T3 or negedge CLR) begin
    // 启动时自动复位
    if (CLR == 0) begin
        LPC <= 1'b0;PCINC <= 1'b0;PCADD <= 1'b0;LAR <= 1'b0;ARINC <= 1'b0;LIR <= 1'b0;DRW <= 1'b0;
        LDZ <= 1'b0;LDC <= 1'b0;S <= 4'b0000; M <= 1'b0;CIN <= 1'b0;MEMW <= 1'b0;ABUS <= 1'b0;
        SBUS <= 1'b0;MBUS <= 1'b0;SEL <= 4'b0000;SELCTL <= 1'b0;STOP <= 1'b0;
        SHORT <= 1'b0;LONG <= 1'b0;
        stall <= 0;IF_valid <= 0;EX_valid <= 0;EX_IR <= 4'b0000;W <= W1;
        STO <= 1'b0;halted <= 1'b0;
    end else begin
        LPC <= 1'b0;PCINC <= 1'b0;PCADD <= 1'b0;LAR <= 1'b0;ARINC <= 1'b0;LIR <= 1'b0;DRW <= 1'b0;
        LDZ <= 1'b0;LDC <= 1'b0;S <= 4'b0000;M <= 1'b0;CIN <= 1'b0;MEMW <= 1'b0;
        ABUS <= 1'b0;SBUS <= 1'b0;MBUS <= 1'b0;SEL <= 4'b0000;SELCTL <= 1'b0;
        STOP <= 1'b0;SHORT <= 1'b0;LONG <= 1'b0;

      if (W == W0) begin
        W   <= W1;
        STO <= 1'b0;
      end 
      else if (halted == 1)begin
        STOP <=1'b1;
        W <=W1;
      end
      else if (W == W1) begin
        case (SW)
          // W1作为普通流水拍
          FETCH: begin
            EX_IR <= IR;
            EX_valid <= IF_valid;
            // IF取指阶段
            if (!stall) begin
              LIR <= 1;
              PCINC <= 1;
              IF_valid <= 1;
            end else begin
              LIR <= 0;
              PCINC <= 0;
              IF_valid <= 0;
            end
            // EX执行阶段
            if (EX_valid) begin
              case (EX_IR)
                ADD: begin
                  S <= 4'b1001;
                  CIN <= 1'b1;
                  ABUS <= 1'b1;
                  DRW <= 1'b1;
                  LDZ <= 1'b1;
                  LDC <= 1'b1;
                  W <= W1;
                end
                SUB: begin
                  S <= 4'b0110;
                  CIN <= 1'b0;
                  ABUS <= 1'b1;
                  DRW <= 1'b1;
                  LDZ <= 1'b1;
                  LDC <= 1'b1;
                  W <= W1;
                end
                AND: begin
                  S <= 4'b1011;
                  M <= 1'b1;
                  ABUS <= 1'b1;
                  DRW <= 1'b1;
                  LDZ <= 1'b1;
                  W <= W1;
                end
                INC: begin
                  S <= 4'b0000;
                  CIN <= 1'b0;
                  ABUS <= 1'b1;
                  DRW <= 1'b1;
                  LDZ <= 1'b1;
                  LDC <= 1'b1;
                  W <= W1;
                end
                LD: begin
                  S <= 4'b1010;
                  M <= 1'b1;
                  ABUS <= 1'b1;
                  LAR <= 1'b1;
                  // LD/ST不是错路径跳转，保留已经预取到IR的下一条指令。
                  // 这里只暂停继续取指，并让EX在访存拍期间为空。
                  LIR <= 1'b0;
                  PCINC <= 1'b0;
                  IF_valid <= 1'b1;
                  EX_valid <= 1'b0;
                  W <= W2;
                  // 本拍依旧执行LD指令
                  EX_IR <= EX_IR;
                end
                ST: begin
                  S <= 4'b1111;
                  M <= 1'b1;
                  ABUS <= 1'b1;
                  LAR <= 1'b1;
                  // LD/ST不是错路径跳转，保留已经预取到IR的下一条指令。
                  // 这里只暂停继续取指，并让EX在访存拍期间为空。
                  LIR <= 1'b0;
                  PCINC <= 1'b0;
                  IF_valid <= 1'b1;
                  EX_valid <= 1'b0;
                  W <= W2;
                  // 本拍依旧执行ST指令
                  EX_IR <= EX_IR;
                end
                JC: begin
                  if (C) begin
                        PCADD <= 1'b1;
                        LIR <= 1'b0;
                        PCINC <= 1'b0;
                        IF_valid <= 1'b0;
                        EX_valid <= 1'b0;
                  end
                  else begin end
                        W <= W1;
                end
                JZ: begin
                  if (Z) begin
                        PCADD <= 1'b1;
                        LIR <= 1'b0;
                        PCINC <= 1'b0;
                        IF_valid <= 1'b0;
                        EX_valid <= 1'b0;
                  end
                  else begin end
                        W <= W1;
                end
                JMP: begin
                  S <= 4'b1111;
                  M <= 1'b1;
                  ABUS <= 1'b1;
                  LPC <= 1'b1;
                  W <= W1;
                  IF_valid <= 1'b0;
                  EX_valid <= 1'b0;
                  LIR <= 1'b0;
                  PCINC <= 1'b0;
                end
                STP: begin
                  STOP <= 1'b1;
                  halted <= 1'b1;
                  LIR <= 1'b0;
                  PCINC <= 1'b0;
                  IF_valid <= 1'b0;
                  EX_valid <= 1'b0;
                  W <= W1;
                end
                default: begin
                  W <= W1;
                end
              endcase
            end else begin
            end
          end
          WREG: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            if (!STO) begin
              SBUS <= 1'b1;
              SEL <= 4'b0011;
              SELCTL <= 1'b1;
              DRW <= 1'b1;
              STOP <= 1'b1;
              W <= W2;
            end else begin
              SBUS <= 1'b1;
              SEL <= 4'b1001;
              SELCTL <= 1'b1;
              DRW <= 1'b1;
              STOP <= 1'b1;
              W <= W2;
            end
          end
          RREG: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            SEL <= 4'b0001;
            SELCTL <= 1'b1;
            STOP <= 1'b1;
            W <= W2;
            STO <= 1'b0;
          end
          RMEM: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            if (!STO) begin
              SBUS <= 1'b1;
              LAR <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end else begin
              MBUS <= 1'b1;
              ARINC <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end
          end
          WMEM: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            if (!STO) begin
              SBUS <= 1'b1;
              LAR <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end else begin
              SBUS <= 1'b1;
              MEMW <= 1'b1;
              ARINC <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end
          end
          default: begin
            W <= W1;
          end
        endcase
      end else if (W == W2) begin
        case (SW)
          FETCH: begin
                case (EX_IR)
                LD: begin
                        DRW <= 1'b1;
                        MBUS <= 1'b1;
                        W <= W1;
                end
                ST: begin
                        S <= 4'b1010;
                        M <= 1'b1;
                        ABUS <= 1'b1;
                        MEMW <= 1'b1;
                        W <= W1;
                end
                default: begin
                        W <= W1;
                end
                endcase
                end 
          WREG: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            if (!STO) begin
              SBUS <= 1'b1;
              SEL <= 4'b0100;
              SELCTL <= 1'b1;
              DRW <= 1'b1;
              STOP <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end else begin
              SBUS <= 1'b1;
              SEL <= 4'b1110;
              SELCTL <= 1'b1;
              DRW <= 1'b1;
              STOP <= 1'b1;
              W <= W0;
              STO <= 1'b1;
            end
          end
          RREG: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            SEL <= 4'b1011;
            SELCTL <= 1'b1;
            STOP <= 1'b1;
            W <= W0;
            STO <= 1'b0;
          end
          WMEM: begin
                EX_IR <= 4'b0000;
                IF_valid <= 1'b0;
                EX_valid <= 1'b0;
            if (!STO) begin
              SBUS <= 1'b1;
              LAR <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end else begin
              SBUS <= 1'b1;
              MEMW <= 1'b1;
              ARINC <= 1'b1;
              STOP <= 1'b1;
              SHORT <= 1'b1;
              SELCTL <= 1'b1;
              W <= W1;
              STO <= 1'b1;
            end
          end
          default: begin
            W <= W1;
          end
        endcase
      end
      // 最新版本没有路径主动进入W3，但为防止历史遗留问题放一个兜底
      else if (W == W3) begin
        W<=W1;
      end
    end
  end

endmodule
