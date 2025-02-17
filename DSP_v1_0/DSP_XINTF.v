`timescale 1 ns / 1 ps

/*

MPS DSP_XNITF Module
개발 4팀 전경원 차장

24.06.12 :	최초 생성
24.07.08 :  i_DSP_intr을 한번이라도 Clear한 후에 FSM동작되게 수정
			따라서 FSM DONE 추가
24.07.11 : 	DPBRAM의 데이터 R/W가 2 Clock이 필요하여 추가함
			dpbram_Setup_flag 참고

이성진 차장의 퇴사로 인하여 MPS PL 프로그래밍

0. 기타
 - 

1. DSP_XINTF
 - DSP External Interface
 - EPICS와 DSP가 DPBRAM에 데이터를 읽고 쓰는 용도

2. FSM
 - IDLE - WRITE - DELAY - READ
 - DSP에서 Interrupt 발생 시 동작 (i_DSP_intr)

 2.1 이성진 코드
  - IDLE : 0 Count
  - WRITE : 25 Count
  - READY : 1498 + WRITE Count
  - READ : Total 1900 Count
  - 해당하는 Count 마다 FSM State가 바뀜

 2.2 WRITE (250ns)
  - EPICS IOC - DPBRAM
  - 25 Count (125ns)
  - 24.07.11로 인하여 50 Count로 변경 (250ns)
  - addr 124부터 149까지 증가함

 2.3 DELAY (7290ns)
  - 1498 Count (7495ns)
  - 24.07.11로 인하여 WRITE의 시간이 변경되어 1458 Count로 변경.
  - DSP에서 DPBRAM에 데이터 읽고 쓰는 시간

 2.4 READ (1250ns)
  - addr 0부터 124까지 증가함
  - 24.07.11로 인하여  250 Count로 변경

3. Time (8790ns)
 - 기존 : WRITE 125ns + DELAY 7495ns + READ 625ns
 - 변경 : 250 + 7290 + 1250 = 8790ns

*/

module DSP_XINTF
(
	input i_clk,
	input i_rst,

	input i_DSP_intr,
	input [15:0] i_INTL_state,

	input [15:0] i_Write_Index,
	input [31:0] i_Write_DATA,
	input [15:0] i_WF_dsp,
	input [31:0] i_WF_data,

	input [15:0] i_xintf_PL_ram_dout,
	output reg [8:0] o_xintf_PL_ram_addr,
	output reg o_xintf_PL_ram_ce,
	output reg o_xintf_PL_ram_we,
	output reg [15:0] o_xintf_PL_ram_din,

	input [31:0] i_c_adc_data,
	input [31:0] i_v_adc_data,

	output [31:0] o_DSP_Duty,
    output [31:0] o_DSP_FaultNum,
    output [31:0] o_DSP_System_Status,
    output [15:0] o_DSP_EIS,
    output [31:0] o_DSP_R_Load,
    output [15:0] o_DSP_MPS_TYPE,
    output [31:0] o_DSP_SetCurrRD,
    output [31:0] o_DSP_DEGCurrentRD,
    output [31:0] o_DSP_DEGPeriod,
    output [31:0] o_DSP_OverCurrent,
    output [31:0] o_DSP_LowVoltage,
    output [31:0] o_DSP_OverVoltage,
    output [31:0] o_DSP_OverTemp,
    output [31:0] o_DSP_CurrentHighLimit,
    output [31:0] o_DSP_Vpgain,
    output [31:0] o_DSP_ViGain,
    output [31:0] o_DSP_CurrentPgain,
    output [31:0] o_DSP_CurrentIgain,
    output [31:0] o_DSP_Max_Duty,
    output [15:0] o_DSP_DSP_Code,
    output [15:0] o_DSP_SlewRate,
    output [15:0] o_DSP_osc_state,
    output [15:0] o_DSP_remote_state,
    output [31:0] o_DSP_regulation_time,
    output [31:0] o_DSP_Current_Factor,
    output [31:0] o_DSP_Voltage_Factor,
    output [31:0] o_DSP_Input_Voltage_Factor,
    output [31:0] o_DSP_Current_Offset_Set,
    output [15:0] o_DSP_Deadband_Set,
    output [15:0] o_DSP_Dual_Offset_Deadband_Set,
    output [31:0] o_DSP_PI_Max_V,
    output [31:0] o_DSP_PI_Min_V,
    output [31:0] o_DSP_Eruption_V,
    output [31:0] o_DSP_Eruption_C,
    output [31:0] o_F_DSP_ADC_C,
    output [31:0] o_F_DSP_ADC_V,

	output o_WF_Counter_flag,
	output [2:0] o_debug_fsm_state,
	output reg dpbram_Setup_flag
);

	parameter IDLE	= 0;
	parameter WRITE	= 1;
	parameter DELAY	= 2;
	parameter READ	= 3;
	parameter DONE	= 4;

	// FSM
	reg [2:0] state;
	reg [2:0] n_state;

	// Count
	reg [10:0] delay_cnt;

	// Flag
	wire delay_comp_flag;

	// FSM Control
	always @(posedge i_clk or negedge i_rst)
    begin
        if (~i_rst)
            state <= IDLE;

        else 
            state <= n_state;
    end

	// FSM
	always @(*)
    begin
        case (state)
            IDLE :
            begin
                if (i_DSP_intr)
                    n_state <= WRITE;

                else
                    n_state <= IDLE;
            end

			// PS -> DSP
			WRITE :
            begin
                if (o_xintf_PL_ram_addr == 149)
                    n_state <= DELAY;

                else
                    n_state <= WRITE;
            end

			DELAY :
            begin
                if (delay_comp_flag)
                    n_state <= READ;

                else
                    n_state <= DELAY;
            end

			// DSP -> Zynq
			READ :
            begin
                if (o_xintf_PL_ram_addr == 124)
                    n_state <= DONE;

                else
                    n_state <= READ;
            end

			// i_DSP_intr Clear
			DONE :
            begin
                if (~i_DSP_intr)
                    n_state <= IDLE;

                else
                    n_state <= DONE;
            end

			default :
                    n_state <= n_state;
		endcase
	end

	// DPBRAM Data R/W 2 Clock
	always @(posedge i_clk or negedge i_rst) 
    begin
        if (~i_rst)
            dpbram_Setup_flag <= 0;

		else if ((state == WRITE) || (state == READ))
			dpbram_Setup_flag <= ~dpbram_Setup_flag;

		else
			dpbram_Setup_flag <= 0;
	end

	// DELAY Count. 1458 Count (Look up assign)
	always @(posedge i_clk or negedge i_rst) 
    begin
        if (~i_rst)
            delay_cnt <= 0;

		else if (state == DELAY)
			delay_cnt <= delay_cnt + 1;

		else
			delay_cnt <= 0;
	end

	// DPBRAM CE, WE
	always @(posedge i_clk or negedge i_rst) 
    begin
        if (~i_rst)
		begin
            o_xintf_PL_ram_ce <= 0;
			o_xintf_PL_ram_we <= 0;
		end

		else if (state == WRITE)
		begin
            o_xintf_PL_ram_ce <= 1;
			o_xintf_PL_ram_we <= 1;
		end

		else if (state == READ)
		begin
            o_xintf_PL_ram_ce <= 1;
			o_xintf_PL_ram_we <= 0;
		end

		else
		begin
            o_xintf_PL_ram_ce <= 0;
			o_xintf_PL_ram_we <= 0;
		end
	end

	always @(posedge i_clk or negedge i_rst) 
    begin
        if (~i_rst)
			o_xintf_PL_ram_addr <= 124;

		else if (state == IDLE)
			o_xintf_PL_ram_addr <= 124;
		
		else if ((state == WRITE) && (~dpbram_Setup_flag))
			o_xintf_PL_ram_addr <= o_xintf_PL_ram_addr + 1;

		else if (state == DELAY)
			o_xintf_PL_ram_addr <= 0;

		else if ((state == READ) && (~dpbram_Setup_flag))
			o_xintf_PL_ram_addr <= o_xintf_PL_ram_addr + 1;

		else
			o_xintf_PL_ram_addr <= o_xintf_PL_ram_addr;
	end

	// DPBRAM WRITE
	always @(posedge i_clk or negedge i_rst) 
    begin
        if (~i_rst)
			o_xintf_PL_ram_din <= 0;

		else if (state == WRITE)
		begin
			if (o_xintf_PL_ram_addr == 127)
				o_xintf_PL_ram_din <= i_c_adc_data[15:0];

			else if (o_xintf_PL_ram_addr == 128)
				o_xintf_PL_ram_din <= i_c_adc_data[31:16];

			else if (o_xintf_PL_ram_addr == 129)
				o_xintf_PL_ram_din <= i_v_adc_data[15:0];

			else if (o_xintf_PL_ram_addr == 130)
				o_xintf_PL_ram_din <= i_v_adc_data[31:16];

			else if (o_xintf_PL_ram_addr == 131)
				o_xintf_PL_ram_din <= i_INTL_state;

			else if (o_xintf_PL_ram_addr == 132)
				o_xintf_PL_ram_din <= i_WF_dsp;

			else if (o_xintf_PL_ram_addr == 133)
				o_xintf_PL_ram_din <= i_WF_data[15:0];

			else if (o_xintf_PL_ram_addr == 134)
				o_xintf_PL_ram_din <= i_WF_data[31:16];

			else if (o_xintf_PL_ram_addr == 143)
				o_xintf_PL_ram_din <= i_Write_Index;

			else if (o_xintf_PL_ram_addr == 144)
				o_xintf_PL_ram_din <= i_Write_DATA[15:0];

			else if (o_xintf_PL_ram_addr == 145)
				o_xintf_PL_ram_din <= i_Write_DATA[31:16];

			else
				o_xintf_PL_ram_din <= 0;
		end

		else 
			o_xintf_PL_ram_din <= 0;
	end

	assign o_debug_fsm_state = state;
	assign delay_comp_flag = (delay_cnt == 1458) ? 1 : 0;
	assign o_WF_Counter_flag = delay_comp_flag;

	assign o_F_DSP_ADC_C[15:0] = ((state == WRITE) && (o_xintf_PL_ram_addr == 127)) ? i_c_adc_data[15:0] : o_F_DSP_ADC_C[15:0];
	assign o_F_DSP_ADC_C[31:16] = ((state == WRITE) && (o_xintf_PL_ram_addr == 128)) ? i_c_adc_data[31:16] : o_F_DSP_ADC_C[31:16];
	assign o_F_DSP_ADC_V[15:0] = ((state == WRITE) && (o_xintf_PL_ram_addr == 129)) ? i_v_adc_data[15:0] : o_F_DSP_ADC_V[15:0];
	assign o_F_DSP_ADC_V[31:16] = ((state == WRITE) && (o_xintf_PL_ram_addr == 130)) ? i_v_adc_data[31:16] : o_F_DSP_ADC_V[31:16];

	// DPBRAM READ
	assign o_DSP_Duty[15:0] 					= ((state == READ) && (o_xintf_PL_ram_addr == 6)) ? i_xintf_PL_ram_dout : o_DSP_Duty[15:0];
	assign o_DSP_Duty[31:16] 					= ((state == READ) && (o_xintf_PL_ram_addr == 7)) ? i_xintf_PL_ram_dout : o_DSP_Duty[31:16];
	assign o_DSP_FaultNum[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 8)) ? i_xintf_PL_ram_dout : o_DSP_FaultNum[15:0];
	assign o_DSP_System_Status[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 9)) ? i_xintf_PL_ram_dout : o_DSP_System_Status[15:0];
	assign o_DSP_System_Status[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 11)) ? i_xintf_PL_ram_dout : o_DSP_System_Status[31:16];
	assign o_DSP_EIS 							= ((state == READ) && (o_xintf_PL_ram_addr == 10)) ? i_xintf_PL_ram_dout : o_DSP_EIS;

	assign o_DSP_R_Load[15:0] 					= ((state == READ) && (o_xintf_PL_ram_addr == 14)) ? i_xintf_PL_ram_dout : o_DSP_R_Load[15:0];
	assign o_DSP_R_Load[31:16] 					= ((state == READ) && (o_xintf_PL_ram_addr == 15)) ? i_xintf_PL_ram_dout : o_DSP_R_Load[31:16];

	assign o_DSP_MPS_TYPE 						= ((state == READ) && (o_xintf_PL_ram_addr == 17)) ? i_xintf_PL_ram_dout : o_DSP_MPS_TYPE;
	assign o_DSP_SetCurrRD[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 18)) ? i_xintf_PL_ram_dout : o_DSP_SetCurrRD[15:0];
	assign o_DSP_SetCurrRD[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 19)) ? i_xintf_PL_ram_dout : o_DSP_SetCurrRD[31:16];
	assign o_DSP_DEGCurrentRD[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 20)) ? i_xintf_PL_ram_dout : o_DSP_DEGCurrentRD[15:0];
	assign o_DSP_DEGCurrentRD[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 21)) ? i_xintf_PL_ram_dout : o_DSP_DEGCurrentRD[31:16];
	assign o_DSP_DEGPeriod[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 22)) ? i_xintf_PL_ram_dout : o_DSP_DEGPeriod[15:0];
	assign o_DSP_DEGPeriod[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 23)) ? i_xintf_PL_ram_dout : o_DSP_DEGPeriod[31:16];
	assign o_DSP_OverCurrent[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 24)) ? i_xintf_PL_ram_dout : o_DSP_OverCurrent[15:0];
	assign o_DSP_OverCurrent[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 25)) ? i_xintf_PL_ram_dout : o_DSP_OverCurrent[31:16];
	assign o_DSP_LowVoltage[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 26)) ? i_xintf_PL_ram_dout : o_DSP_LowVoltage[15:0];
	assign o_DSP_LowVoltage[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 27)) ? i_xintf_PL_ram_dout : o_DSP_LowVoltage[31:16];
	assign o_DSP_OverVoltage[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 28)) ? i_xintf_PL_ram_dout : o_DSP_OverVoltage[15:0];
	assign o_DSP_OverVoltage[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 29)) ? i_xintf_PL_ram_dout : o_DSP_OverVoltage[31:16];
	assign o_DSP_OverTemp[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 30)) ? i_xintf_PL_ram_dout : o_DSP_OverTemp[15:0];
	assign o_DSP_OverTemp[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 31)) ? i_xintf_PL_ram_dout : o_DSP_OverTemp[31:16];
	assign o_DSP_CurrentHighLimit[15:0] 		= ((state == READ) && (o_xintf_PL_ram_addr == 32)) ? i_xintf_PL_ram_dout : o_DSP_CurrentHighLimit[15:0];
	assign o_DSP_CurrentHighLimit[31:16] 		= ((state == READ) && (o_xintf_PL_ram_addr == 33)) ? i_xintf_PL_ram_dout : o_DSP_CurrentHighLimit[31:16];
	assign o_DSP_Vpgain[15:0] 					= ((state == READ) && (o_xintf_PL_ram_addr == 34)) ? i_xintf_PL_ram_dout : o_DSP_Vpgain[15:0];
	assign o_DSP_Vpgain[31:16] 					= ((state == READ) && (o_xintf_PL_ram_addr == 35)) ? i_xintf_PL_ram_dout : o_DSP_Vpgain[31:16];
	assign o_DSP_ViGain[15:0] 					= ((state == READ) && (o_xintf_PL_ram_addr == 36)) ? i_xintf_PL_ram_dout : o_DSP_ViGain[15:0];
	assign o_DSP_ViGain[31:16] 					= ((state == READ) && (o_xintf_PL_ram_addr == 37)) ? i_xintf_PL_ram_dout : o_DSP_ViGain[31:16];
	assign o_DSP_CurrentPgain[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 38)) ? i_xintf_PL_ram_dout : o_DSP_CurrentPgain[15:0];
	assign o_DSP_CurrentPgain[31:16]			= ((state == READ) && (o_xintf_PL_ram_addr == 39)) ? i_xintf_PL_ram_dout : o_DSP_CurrentPgain[31:16];
	assign o_DSP_CurrentIgain[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 40)) ? i_xintf_PL_ram_dout : o_DSP_CurrentIgain[15:0];
	assign o_DSP_CurrentIgain[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 41)) ? i_xintf_PL_ram_dout : o_DSP_CurrentIgain[31:16];
	assign o_DSP_Max_Duty[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 42)) ? i_xintf_PL_ram_dout : o_DSP_Max_Duty[15:0];
	assign o_DSP_Max_Duty[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 43)) ? i_xintf_PL_ram_dout : o_DSP_Max_Duty[31:16];
	assign o_DSP_DSP_Code 						= ((state == READ) && (o_xintf_PL_ram_addr == 44)) ? i_xintf_PL_ram_dout : o_DSP_DSP_Code;
	assign o_DSP_SlewRate 						= ((state == READ) && (o_xintf_PL_ram_addr == 45)) ? i_xintf_PL_ram_dout : o_DSP_SlewRate;

	assign o_DSP_osc_state 						= ((state == READ) && (o_xintf_PL_ram_addr == 72)) ? i_xintf_PL_ram_dout : o_DSP_osc_state;
	assign o_DSP_remote_state 					= ((state == READ) && (o_xintf_PL_ram_addr == 73)) ? i_xintf_PL_ram_dout : o_DSP_remote_state;
	assign o_DSP_regulation_time[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 74)) ? i_xintf_PL_ram_dout : o_DSP_regulation_time[15:0];
	assign o_DSP_regulation_time[31:16] 		= ((state == READ) && (o_xintf_PL_ram_addr == 75)) ? i_xintf_PL_ram_dout : o_DSP_regulation_time[31:16];
	assign o_DSP_Current_Factor[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 76)) ? i_xintf_PL_ram_dout : o_DSP_Current_Factor[15:0];
	assign o_DSP_Current_Factor[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 77)) ? i_xintf_PL_ram_dout : o_DSP_Current_Factor[31:16];
	assign o_DSP_Voltage_Factor[15:0] 			= ((state == READ) && (o_xintf_PL_ram_addr == 78)) ? i_xintf_PL_ram_dout : o_DSP_Voltage_Factor[15:0];
	assign o_DSP_Voltage_Factor[31:16] 			= ((state == READ) && (o_xintf_PL_ram_addr == 79)) ? i_xintf_PL_ram_dout : o_DSP_Voltage_Factor[31:16];
	assign o_DSP_Input_Voltage_Factor[15:0] 	= ((state == READ) && (o_xintf_PL_ram_addr == 80)) ? i_xintf_PL_ram_dout : o_DSP_Input_Voltage_Factor[15:0];
	assign o_DSP_Input_Voltage_Factor[31:16] 	= ((state == READ) && (o_xintf_PL_ram_addr == 81)) ? i_xintf_PL_ram_dout : o_DSP_Input_Voltage_Factor[31:16];
	assign o_DSP_Current_Offset_Set[15:0] 		= ((state == READ) && (o_xintf_PL_ram_addr == 82)) ? i_xintf_PL_ram_dout : o_DSP_Current_Offset_Set[15:0];
	assign o_DSP_Current_Offset_Set[31:16] 		= ((state == READ) && (o_xintf_PL_ram_addr == 83)) ? i_xintf_PL_ram_dout : o_DSP_Current_Offset_Set[31:16];
	assign o_DSP_Deadband_Set 					= ((state == READ) && (o_xintf_PL_ram_addr == 84)) ? i_xintf_PL_ram_dout : o_DSP_Deadband_Set;
	
	assign o_DSP_Dual_Offset_Deadband_Set 		= ((state == READ) && (o_xintf_PL_ram_addr == 86)) ? i_xintf_PL_ram_dout : o_DSP_Dual_Offset_Deadband_Set;
	
	assign o_DSP_PI_Max_V[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 88)) ? i_xintf_PL_ram_dout : o_DSP_PI_Max_V[15:0];
	assign o_DSP_PI_Max_V[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 89)) ? i_xintf_PL_ram_dout : o_DSP_PI_Max_V[31:16];
	assign o_DSP_PI_Min_V[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 90)) ? i_xintf_PL_ram_dout : o_DSP_PI_Min_V[15:0];
	assign o_DSP_PI_Min_V[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 91)) ? i_xintf_PL_ram_dout : o_DSP_PI_Min_V[31:16];
	assign o_DSP_Eruption_V[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 92)) ? i_xintf_PL_ram_dout : o_DSP_Eruption_V[15:0];
	assign o_DSP_Eruption_V[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 93)) ? i_xintf_PL_ram_dout : o_DSP_Eruption_V[31:16];
	assign o_DSP_Eruption_C[15:0] 				= ((state == READ) && (o_xintf_PL_ram_addr == 94)) ? i_xintf_PL_ram_dout : o_DSP_Eruption_C[15:0];
	assign o_DSP_Eruption_C[31:16] 				= ((state == READ) && (o_xintf_PL_ram_addr == 95)) ? i_xintf_PL_ram_dout : o_DSP_Eruption_C[31:16];

endmodule