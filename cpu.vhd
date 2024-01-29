library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

ENTITY cpu IS
 port (
		 clk   : in  std_logic;                       -- main clock
		 reset : in  std_logic;                       -- reset button

		 PCview : out std_logic_vector( 7 downto 0);  -- debugging outputs
		 IRview : out std_logic_vector(15 downto 0);
		 RAview : out std_logic_vector(15 downto 0);
		 RBview : out std_logic_vector(15 downto 0);
		 RCview : out std_logic_vector(15 downto 0);
		 RDview : out std_logic_vector(15 downto 0);
		 REview : out std_logic_vector(15 downto 0);

		 iport : in  std_logic_vector(7 downto 0);    -- input port
		 oport : out std_logic_vector(15 downto 0)  -- output port
		);
END cpu;


architecture rtl of cpu is

component ProgramRom
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;
	
	
	component DataRAM
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		wren		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;

  component alu
  port (
    srcA : in  unsigned(15 downto 0);         -- input A
    srcB : in  unsigned(15 downto 0);         -- input B
    op   : in  std_logic_vector(2 downto 0);  -- operation
    cr   : out std_logic_vector(3 downto 0);  -- condition outputs
    dest : out unsigned(15 downto 0));        -- output value
  end component;

  
	type state_type is (Start, Fetch, ExecuteSetup, ExecuteALU, ExecuteMemoryWait, ExecuteWrite,  ExecuteReturnPause1, ExecuteReturnPause2, Halt);

	-- Register to hold the current state
	signal state   : state_type;
	
	signal RA : std_logic_vector(15 downto 0);
	signal RB : std_logic_vector(15 downto 0);
	signal RC : std_logic_vector(15 downto 0);
	signal RD : std_logic_vector(15 downto 0);
	signal RE : std_logic_vector(15 downto 0);
	signal SP : std_logic_vector(15 downto 0);
	signal IR : std_logic_vector(15 downto 0);
	signal PC : std_logic_vector(7 downto 0);
	signal CR : std_logic_vector(3 downto 0);
	signal srcA : unsigned(15 downto 0);
	signal srcB: unsigned(15 downto 0);
	signal dest: unsigned(15 downto 0);
	signal OUTREG: std_logic_vector(15 downto 0);
	signal ROMDataOut: std_logic_vector(15 downto 0);
	signal RAMDataOut: std_logic_vector(15 downto 0);
	signal RAM_Write_enable : std_logic;
	signal ALU_Opcode : std_logic_vector(2 downto 0);
	signal ALU_CR : std_logic_vector(3 downto 0);
	signal MAR : std_logic_vector( 7 downto 0);
	signal MBR: std_logic_vector( 15 downto 0);
	signal count : std_logic_vector( 2 downto 0);
	
	
	begin
	process(clk,reset)
	begin
	if reset = '0' then
		PC <= (others =>'0');
		IR <= (others =>'0');
		OUTREG <= (others =>'0');
		MAR <= (others =>'0');
		MBR <= (others =>'0');
		RA <= (others =>'0');
		RB <= (others =>'0');
		RC <= (others =>'0');
		RD <= (others =>'0');
		RE <= (others =>'0');
		SP <= (others =>'0');
		CR <= (others =>'0');
		count <= (others =>'0');
		state <= start; 
	elsif (rising_edge(clk)) then -- Checking if rising edge of clock
		case state is
			when Start =>
				if count = "111" then
					state <= Fetch;
				end if;
				count <= count + 1;
			when Fetch =>
				IR <= ROMDataOut;
				PC <= PC + 1;
				state <= ExecuteSetup; -- Transitioning to ExecuteSetup state
				
			when ExecuteSetup=>
				ALU_Opcode <= IR(14 downto 12); 
				case IR(15 downto 12) is
					when "0000" => -- load instructions
						if IR(11) = '1' then
							MAR <= IR(7 downto 0) + RE(7 downto 0);
						else
							MAR <= IR(7 downto 0);
						end if;
					
					when "0001" => -- store intructions
						if IR(11) = '1' then
							MAR <= IR(7 downto 0)  +  RE(7 downto 0);
						else
							MAR <= IR(7 downto 0);
						end if;
							case IR(10 downto 8) is 
								when "000" =>
									MBR <= RA;
								when "001" =>
									MBR <= RB;
								when "010" =>
									MBR <= RC;
								when "011" =>
									MBR <= RD;
								when "100" =>
									MBR <= RE;
								when "101" =>
									MBR <= SP;
								when others =>
									null;
							end case;
							
					when "0010" =>  --unconditional branch
						PC <= IR(7 downto 0);
						
					when "0011" => --conditional branch
						case IR(11 downto 10) is
							when "00" =>
								case IR(9 downto 8) is
									when "00" =>
										if CR(0) = '1' then
											PC <= IR(7 downto 0);
										end if;
									when "01" =>
										if CR(1) = '1' then
											PC <= IR(7 downto 0);
										end if;
									when "10" =>
										if CR(2) = '1' then
											PC <= IR(7 downto 0);
										end if;
									when "11" =>
										if CR(3) = '1' then
											PC <= IR(7 downto 0);
										end if;
									when others =>
										null;
								end case;
								
							when "01" => -- call
								PC <= IR(7 downto 0);
								MAR <= SP( 7 downto 0);
								MBR <= "0000" & CR & PC;
								SP <= SP + 1;
								
							when "10" => --return
								MAR <= SP(7 downto 0) - 1;
								SP <= SP - 1;
							when "11" => --exit instruction
--								state <= halt;
							when others =>
								null;
						end case;
					when "0100" => --push
						MAR <= SP(7 downto 0);
						SP <= SP + 1;
						case IR(11 downto 9) is
							when "000" =>
								MBR <= RA;
							when "001" =>
								MBR <= RB;
							when "010" =>
								MBR <= RC;
							when "011" =>
								MBR <= RD;
							when "100" =>
								MBR <= RE;
							when "101" =>
								MBR <= SP;
							when "110" =>
								MBR <= "00000000" & PC;
							when "111" =>
								MBR <= "000000000000" & CR;
							when others =>
								null;
						end case;
					when "0101"	 =>
						MAR <= SP(7 downto 0) - 1;
						SP <= SP - 1;
					when "0110" =>
						null;
					when "0111" =>
						null;
					when "1000" | "1001" | "1010" | "1011" | "1100" =>
						case IR(11 downto 9) is
							when "000" =>
								srcA <= unsigned(RA);
							when "001" => 	
								srcA <= unsigned(RB);
							when "010" =>
								srcA <= unsigned(RC);
							when "011" =>
								srcA <= unsigned(RD);
							when "100" =>
								srcA <= unsigned(RE);
							when "101" =>
								srcA <= unsigned(SP);
							when "110" =>
								srcA <= "0000000000000000";
							when "111" =>
								srcA <= "1111111111111111";
							when others =>
								null;
					  end case;
						
					  case IR(8 downto 6) is
							when "000" =>
								srcB <= unsigned(RA);
							when "001" => 	
								srcB <= unsigned(RB);
							when "010" =>
								srcB <= unsigned(RC);
							when "011" =>
								srcB <= unsigned(RD);
							when "100" =>
								srcB <= unsigned(RE);
							when "101" =>
								srcB <= unsigned(SP);
							when "110" =>
								srcB <= "0000000000000000";
							when "111" =>
								srcB <= "1111111111111111";	
				
							when others =>
								null;
					 end case;
					 
					
				when "1101" =>  --shift operation
						case IR(10 downto 8) is
							when "000" =>
								srcA <= unsigned(RA);
							when "001" => 	
								srcA <= unsigned(RB);
							when "010" =>
								srcA <= unsigned(RC);
							when "011" =>
								srcA <= unsigned(RD);
							when "100" =>
								srcA <= unsigned(RE);
							when "101" =>
								srcA <= unsigned(SP);
							when "110" =>
								srcA <= "0000000000000000";
							when "111" =>
								srcA <= "1111111111111111";
							when others =>
								null;
					  end case;
					  
					   case IR(11) is
							when '0' =>
								srcB <= "0000000000000000";
							when '1' =>
								srcB <= "0000000000000001";
							when others => null;
					  end case;			
									
				when "1110" => --
					case IR(10 downto 8) is
						when "000" =>
							srcA <= unsigned(RA);
						when "001" => 	
							srcA <= unsigned(RB);                                                                                                                                      
						when "010" =>
							srcA <= unsigned(RC);
						when "011" =>
							srcA <= unsigned(RD);
						when "100" =>
							srcA <= unsigned(RE);
						when "101" =>
							srcA <= unsigned(SP);
						when "110" =>
							srcA <= "0000000000000000";
						when "111" =>
							srcA <= "1111111111111111";
						when others =>
							null;
					  end case;
				
				     case IR(11) is
							when '0' =>
								srcB <= "0000000000000000";
							when '1' =>
								srcB <= "0000000000000001";
							when others => null;
					  end case;
				
									
				when "1111" =>    --Move operation
					if IR(11) = '1' then
						srcA <= unsigned(IR(10) & IR(10) & IR(10) & IR(10) & IR(10) & IR(10) & IR(10) & IR(10) & IR(10 downto 3));
					else
						case IR(10 downto 8) is
							when "000" =>
								srcA <= unsigned(RA);
							when "001" => 	
								srcA <= unsigned(RB);                                                                                                                                      
							when "010" =>
								srcA <= unsigned(RC);
							when "011" =>
								srcA <= unsigned(RD);
							when "100" =>
								srcA <= unsigned(RE);
							when "101" =>
								srcA <= unsigned(SP);
							when "110" =>
								srcA <=  unsigned("00000000" & PC);
							when "111" =>
								srcA <= unsigned(IR);
							when others =>
								null;
					  end case;
				  end if;
			when others =>
					null;
	      end case;
				if IR(15 downto 10) = "001111" then
					state <= halt;
				else
					state <= ExecuteALU; --transitioning to ExecuteALU satte
				end if;
			when ExecuteALU =>  --Execute ALU
				if IR(15 downto 12) = "0001" or IR(15 downto 10) = "001101" or IR(15 downto 12) = "0100" then
					RAM_Write_enable <= '1';
				end if;
				if IR(15 downto 12) = "0000" or IR(15 downto 10) = "001110" or IR(15 downto 12) = "0101" then
					state <= ExecuteMemoryWait;
				else
					state <= ExecuteWrite;
				end if;
			when ExecuteMemoryWait =>  -- ExecuteWait
				state <= ExecuteWrite;
			
			when ExecuteWrite => -- ExecuteWrite
				RAM_Write_enable <= '0';
				case IR(15 downto 12) is
				when "0000" =>
					case IR(10 downto 8) is
						when "000" =>
							RA <= RAMDataOut;
						when "001" =>
							RB <= RAMDataOut;
						when "010" =>
							RC <= RAMDataOut;
						when "011" =>
							RD <= RAMDataOut;
						when "100" =>
							RE <= RAMDataOut;
						when "101" =>
							SP <= RAMDataOut;
						when others =>
							null;
					end case;
							
				when "0001" =>
					null;
				when "0010" =>
					null;
				when "0100" =>
					null;
				when "0011" =>
					case IR(11 downto 10) is
						when "00" =>
							null;
						when "01" =>
							null;
						when "10" =>
							PC <= RAMDataOut(7 downto 0);
							CR <= RAMDataOut(11 downto 8);
							
						when others =>
							null;
					end case;
							
				when "0101" =>  --pop
					case IR(11 downto 9) is
						when "000" =>
							RA <= RAMDataOut;
						when "001" =>
							RB <= RAMDataOut;
						when "010" =>
							RC <= RAMDataOut;
						when "011" =>
							RD <= RAMDataOut;
						when "100" =>
							RE <= RAMDataOut;
						when "101" =>
							SP <= RAMDataOut;
						when "110" =>
							PC <= RAMDataOut(7 downto 0);
						when "111" =>
							CR <= RAMDataOut(3 downto 0);
						when others =>
							null;
					end case;
							
				when "0110" =>  --write to output port
					case IR(11 downto 9) is
						when "000" =>
							OUTREG <= RA;
						when "001" =>
							OUTREG <= RB;
						when "010" =>
							OUTREG <= RC;
						when "011" =>
							OUTREG <= RD;
						when "100" =>
							OUTREG <= RE;
						when "101" =>
							OUTREG <= SP;
						when "110" =>
							OUTREG <= "00000000" & PC;
						when "111" =>
							OUTREG <= IR;
						when others =>
							null;
					end case;
							
				when "0111" =>  --Load from input port
					case IR(11 downto 9) is
						when "000" =>
							RA <= "00000000" & iport;
						when "001" =>
							RB <= "00000000" & iport;
						when "010" =>
							RC <= "00000000" & iport;
						when "011" =>
							RD <= "00000000" & iport;
						when "100" =>
							RE <= "00000000" & iport;
						when "101" =>
							SP <= "00000000" & iport;
						when others =>
							null;
					end case;
							
				when "1000"  | "1001" | "1010" |"1011" | "1100" | "1101" | "1110" => --Add, subtract, and, or, xor, shift, and rotate
					case IR(2 downto 0) is
						when "000" =>
							RA <= std_logic_vector(dest);
						when "001" =>
							RB <= std_logic_vector(dest);
						when "010" =>
							RC <= std_logic_vector(dest);
						when "011" =>
							RD <= std_logic_vector(dest);
						when "100" =>
							RE <= std_logic_vector(dest);
						when "101" =>
							SP <= std_logic_vector(dest);
						when others =>
							null;
					end case;
					CR <= ALU_CR; 
					
				when "1111" =>
					case IR(2 downto 0) is
						when "000" =>
							RA <= std_logic_vector(dest);
						when "001" =>
							RB <= std_logic_vector(dest);
						when "010" =>
							RC <= std_logic_vector(dest);
						when "011" =>
							RD <= std_logic_vector(dest);
						when "100" =>
							RE <= std_logic_vector(dest);
						when "101" =>
							SP <= std_logic_vector(dest);
						when others =>
							null;
					end case;
					CR <= ALU_CR;
				when others =>
					null;
				end case;
				if IR(15 downto 10) = "001110" then -- return instruction
					state <= ExecuteReturnPause1;
				else
					state <= Fetch;
				end if;
			when ExecuteReturnPause1 =>
				state <= ExecuteReturnPause2;
			
			when ExecuteReturnPause2 =>
				state <= Fetch;
			when others =>
				null;
				
		end case;
	end if;
	end process;

--instanciate the RAM component
	DataRAM1: DataRAM
	port map(
		MAR, clk, MBR, RAM_Write_enable,RAMDataOut
		);
		
		ProgramRom1 : ProgramRom
		port map(
		PC,clk , ROMDataOut
		);
		
		Alu1 : ALU
			port map(
		srcA, srcB, ALU_Opcode, ALU_CR, dest 
		);
	
	 PCView <= PC;
	 IRView <= IR;
	 RAview <= RA;
	 RBView <= RB;
	 RCView <= RC;
	 RDView <= RD;
	 REView <= RE;
	 oport <= OUTREG;
	
end rtl;
