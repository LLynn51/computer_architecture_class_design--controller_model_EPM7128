module controller (
    input  CLR, // 全局复位
    input  T3, // 下降沿有效，全局唯一外界时钟信号
    // 指令
    input  [2:0] SW, //SWC SWB SWA
    input  [3:0] IR, // IR7~4
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
    output reg [3:0] S, // ALU功能选择
    output reg M, // (M=1:逻辑运算；M=0:算术运算)
    output reg CIN, // 进位
    // 总线与访存
    output reg MEMW,ABUS,SBUS,MBUS,
    // MUX多路选择器 
    output reg [3:0] SEL,
    output reg SELCTL, // MUX使能
    output reg DRW, 
    output reg SHORT, LONG, STOP
);
    localparam WREG = 3'b100, RREG = 3'b011, FETCH = 3'b000, RMEM = 3'b010, WMEM = 3'b001;
	localparam ADD = 4'b0001, SUB = 4'b0010, AND = 4'b0011,
	           INC = 4'b0100, LD = 4'b0101, ST = 4'b0110, 
	           STP = 4'b1110,JC = 4'b0111, 
	           JZ = 4'b1000, JMP = 4'b1001;
    reg STO;
    localparam W0 = 3'b000, W1 = 3'b001, W2 = 3'b010, W3 = 3'b100;
    // 时序阶段W1~W3,W0定义为刚刚开机需要一次自动复位
    reg [2:0] W;

    // 控制器主体逻辑
    always @(negedge T3 or negedge CLR) begin
        // 启动时自动复位
        if(CLR == 0) begin
			LPC <= 1'b0; PCINC <= 1'b0; PCADD <= 1'b0;
			LAR <= 1'b0; ARINC <= 1'b0;
			LIR <= 1'b0;
			DRW <= 1'b0;
			LDZ <= 1'b0; LDC <= 1'b0;
			S <= 4'b0000; M <= 1'b0; CIN <= 1'b0;
			MEMW <= 1'b0; ABUS <= 1'b0; SBUS <= 1'b0; MBUS <= 1'b0;
			SEL <= 4'b0000; SELCTL <= 1'b0;
			STOP <= 1'b0; SHORT <= 1'b0; LONG <= 1'b0;
			W <= W1; STO <= 1'b0;
		end
        else begin
			LPC <= 1'b0; PCINC <= 1'b0; PCADD <= 1'b0;
			LAR <= 1'b0; ARINC <= 1'b0;
			LIR <= 1'b0;
			DRW <= 1'b0;
			LDZ <= 1'b0; LDC <= 1'b0;
			S <= 4'b0000; M <= 1'b0; CIN <= 1'b0;
			MEMW <= 1'b0; ABUS <= 1'b0; SBUS <= 1'b0; MBUS <= 1'b0;
			SEL <= 4'b0000; SELCTL <= 1'b0;
			STOP <= 1'b0; SHORT <= 1'b0; LONG <= 1'b0;

            if( W == W0 ) begin
			W <= W1; STO <= 1'b0;
		end
        else if (W == W1) begin
            case (SW)
                FETCH: begin
                        LIR <= 1'b1;
                        PCINC <= 1'b1;
                        W <= W2;
                end
                WREG: begin
                    if (!STO) begin
                            SBUS <= 1'b1;
                            SEL <= 4'b0011;
                            SELCTL <= 1'b1; 
                            DRW <= 1'b1; 
                            STOP <= 1'b1;
                            W <= W2;
                    end 
                    else begin
                            SBUS <= 1'b1;
                            SEL <= 4'b1001;
                            SELCTL <= 1'b1; 
                            DRW <= 1'b1; 
                            STOP <= 1'b1;
                            W <= W2;
                    end
                end
                RREG: begin
                        SEL <= 4'b0001;
                        SELCTL <= 1'b1; STOP <= 1'b1;
                        W <= W2;
                        STO <= 1'b0;
                end
                RMEM: begin
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
        else if (W == W2) begin
            case (SW)
                FETCH: begin
                    case (IR)
                        ADD: begin
                                S <= 4'b1001;
                                CIN <= 1'b1; ABUS <= 1'b1; DRW <= 1'b1;
                                LDZ <= 1'b1; LDC <= 1'b1;
                                W <= W1;
                        end
                        SUB: begin
                                S <= 4'b0110;
                                CIN <= 1'b0; ABUS <= 1'b1; DRW <= 1'b1;
                                LDZ <= 1'b1; LDC <= 1'b1;
                                W <= W1;
                        end
                        AND: begin
                                S <= 4'b1011;
                                M <= 1'b1; ABUS <= 1'b1; DRW <= 1'b1;
                                LDZ <= 1'b1;
                                W <= W1;
                        end
                        INC: begin
                                S <= 4'b0000;
                                CIN <= 1'b0; ABUS <= 1'b1; DRW <= 1'b1;
                                LDZ <= 1'b1; LDC <= 1'b1;
                                W <= W1;
                        end
                        LD: begin
                                S <= 4'b1010;
                                M <= 1'b1; ABUS <= 1'b1; LAR <= 1'b1;
                                LONG <= 1'b1;
                                W <= W3;
                        end
                        ST: begin
                                S <= 4'b1111;
                                M <= 1'b1; ABUS <= 1'b1; LAR <= 1'b1;
                                LONG <= 1'b1;
                                W <= W3;
                        end
                        JC: begin
                                if (C) PCADD <= 1'b1;
                                W <= W1;
                        end
                        JZ: begin
                                if (Z) PCADD <= 1'b1;
                                W <= W1;
                        end
                        JMP: begin
                                S <= 4'b1111;
                                M <= 1'b1; ABUS <= 1'b1; LPC <= 1'b1;
                                W <= W1;
                        end
                        STP: begin
                                STOP <= 1'b1;
                                W <= W1;
                        end
                        default: begin
                                W <= W1;
                        end
                    endcase
                end
                WREG: begin
                    if (!STO) begin
                            SBUS <= 1'b1;
                            SEL <= 4'b0100;
                            SELCTL <= 1'b1; DRW <= 1'b1; STOP <= 1'b1;
                            W <= W1;
                            STO <= 1'b1;
                    end else begin
                            SBUS <= 1'b1;
                            SEL <= 4'b1110;
                            SELCTL <= 1'b1; DRW <= 1'b1; STOP <= 1'b1;
                            LONG <= 1'b1;
                            W <= W0;
                            STO <= 1'b1;
                    end
                end
                RREG: begin
                        SEL <= 4'b1011;
                        SELCTL <= 1'b1; STOP <= 1'b1; LONG <= 1'b1;
                        W <= W0;
                        STO <= 1'b0;
                end
                WMEM: begin
                    if (!STO) begin
                            SBUS <= 1'b1; LAR <= 1'b1; STOP <= 1'b1;
                            SHORT <= 1'b1; SELCTL <= 1'b1;
                            W <= W1;
                            STO <= 1'b1;
                    end else begin
                            SBUS <= 1'b1; MEMW <= 1'b1; ARINC <= 1'b1;
                            STOP <= 1'b1; SHORT <= 1'b1; SELCTL <= 1'b1;
                            W <= W1;
                            STO <= 1'b1;
                    end
                end
                default: begin
                        W <= W1;
                end
            endcase
        end
        else if (W == W3) begin
            case (IR)
                LD: begin
                        DRW <= 1'b1; MBUS <= 1'b1;
                        W <= W1;
                end
                ST: begin
                        S <= 4'b1010;
                        M <= 1'b1; ABUS <= 1'b1; MEMW <= 1'b1;
                        W <= W1;
                end
                default:begin
                        W <= W1;
                end 
            endcase
            end
            else begin
                W <= W1;
            end
        end
    end

endmodule
