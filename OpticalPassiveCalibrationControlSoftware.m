clc;
clear;
format long;
clear instrument_OSA;
clear instrument_OSICS;
clear instrument_U3606;

MODE=1;     % 1-single measurement | 2-continuous measurement | 3- OSA WL CAL | 4- CAL PATH CONT. | 5-CAL | 6-INSERTION LOSS MEAS
            % 7-temperature measurement

devicelist=visadevlist;

instrument_OSA = visadev("GPIB0::1::INSTR");
instrument_OSA.Timeout=1000;        % timeout 100 sek for OSA
idn_OSA=writeread(instrument_OSA,"*IDN?");

instrument_OSICS = visadev("GPIB0::20::INSTR");
instrument_OSICS.Timeout=20;       % timeout 20 sek for OSICS
idn_OSICS=writeread(instrument_OSICS,"*IDN?");

% instrument_U3606 = visadev("GPIB0::3::INSTR");
% instrument_U3606.Timeout=20;       % timeout 20 sek for multimeter
% idn_U3606=writeread(instrument_U3606,"*IDN?");


%-------------------------- INIT OSA --------------------------------------

start_wavelength=1500;            % <600..1750> nm
stop_wavelength=1550.0;             % <600..1750> nm
sample_points =10001;                % 51 | 101 | 251 | 501 | 1001 | 2001 | 5001 | 10001 | 200001 | 500001
resolution = 0.07;                  % 0.07 | 0.1 | 0.2 | 0.5 | 1.0   [nm]
video_bandwith= 1000;               % 10 | 100 | 200 | 1000 | 2000 | 10000 | 100000 | 1000000    [Hz]
reference_level = -20;              % set reference level [dBm] <-90...30>
log_scale_div =5;                   % vertical scale division [dB/div] <0.1...10>
sweep_average_count = 20;            % sweep average count <1...1000>
storage_mode = 'off';               % storage mode of trace: AVS | OFF
active_trace = 'A';                 % A...J
trace_type = 'WRITE';               % BLANK|CALC|FIX|WRITE

span = stop_wavelength - start_wavelength;

osa_set_wavelength_range(instrument_OSA,start_wavelength,stop_wavelength);  
osa_set_sample_points(instrument_OSA,sample_points);  
osa_set_resolution(instrument_OSA,resolution); 
osa_set_video_bandwith(instrument_OSA,video_bandwith);
osa_set_ref_level(instrument_OSA,reference_level);
osa_set_scale_div(instrument_OSA,log_scale_div);
osa_set_sweep_average_count(instrument_OSA,sweep_average_count);
osa_select_storage_mode(instrument_OSA,active_trace,storage_mode);
osa_trace_select(instrument_OSA,active_trace);
osa_set_trace_type(instrument_OSA,active_trace,trace_type);

osa_status=osa_check_instrument_status(instrument_OSA);

%------------------------------ INIT OSICS --------------------------------
% BAR - ECL / CROSS - SENSORS
osics_switch_config(instrument_OSICS,'BAR');    % BAR | CROSS
osics_ecl_enable(instrument_OSICS);
osics_set_ecl_wavelength(instrument_OSICS,1545);
osics_set_ecl_power(instrument_OSICS,-5);
osics_set_atn_value(instrument_OSICS,5);

ecl_power=osics_get_ecl_power(instrument_OSICS);
ecl_wavelength=osics_get_ecl_wavelength(instrument_OSICS);
attenuator=osics_get_atn_value(instrument_OSICS);

%==========================================================================
%------------------ SINGLE MEASUREMENT ------------------------------------

if(MODE == 1)

    tic
    if storage_mode == 'OFF'
        osa_start_measurement(instrument_OSA);
    end
    if storage_mode == 'AVS'
        osa_start_measurement_with_sweep_averaging(instrument_OSA);
    end
    toc

    y_data = osa_get_trace_data(instrument_OSA,active_trace);
    
    x_data=linspace(start_wavelength,stop_wavelength,sample_points);

    plot(x_data,y_data, 'LineWidth',1)
    yline(-56,'--r','Cut level')
    xlabel('vlnova dlzka [nm]')
    ylabel('vykon [dBm]')
    grid on;
    
end

%==========================================================================
%------------------------ continuous  measurement -------------------------

if(MODE == 2)

    meas_count=0;
    meas_period = 600;  % sek
    next_meas_time = round(posixtime(datetime('now')))+5;    % first meas. after 5 sek.

    logfile_name=append('logOSA',date,'.csv');
    create_logfile_header(idn_OSA, instrument_OSA.ResourceName, idn_OSICS, instrument_OSICS.ResourceName, idn_U3606, instrument_U3606.ResourceName, start_wavelength,stop_wavelength,sample_points,resolution,video_bandwith,reference_level,'G.Hencze',logfile_name,meas_period,storage_mode,sweep_average_count,attenuator,ecl_power,ecl_wavelength,span);    
                                                                                                                                                                         
    while true
    
        while true  % wait for next measurement
            time_now = round(posixtime(datetime('now')));
            if time_now == next_meas_time
                break;
            end
        end
        
        clc
        meas_count = meas_count + 1;
        next_meas_time = round(posixtime(datetime('now'))) + meas_period;
        
        %---------- prepnut SWITCH na BAR , spustit meranie
        meas_timestamp=datestr(datetime('now'));
        osics_switch_config(instrument_OSICS,'BAR');
        ecl_power=osics_get_ecl_power(instrument_OSICS);
        ecl_wavelength=osics_get_ecl_wavelength(instrument_OSICS);
        attenuator=osics_get_atn_value(instrument_OSICS);

        if storage_mode == 'OFF'
            osa_start_measurement(instrument_OSA);
        end
        if storage_mode == 'AVS'
            osa_start_measurement_with_sweep_averaging(instrument_OSA);
        end

        pt100_teplota=start_temperature_measurement_with_pt100(instrument_U3606);
           
        y_data = osa_get_trace_data(instrument_OSA,active_trace);
    
        x_data=start_wavelength:(span/(sample_points-1)):stop_wavelength;
    
        save_data(meas_timestamp,start_wavelength,stop_wavelength,'ECL',attenuator,ecl_power,ecl_wavelength,pt100_teplota,y_data,logfile_name);



        %---------- prepnut SWITCH na CROSS , spustit meranie
        meas_timestamp=datestr(datetime('now'));
        osics_switch_config(instrument_OSICS,'CROSS');
        ecl_power=osics_get_ecl_power(instrument_OSICS);
        ecl_wavelength=osics_get_ecl_wavelength(instrument_OSICS);
        attenuator=osics_get_atn_value(instrument_OSICS);

        if storage_mode == 'OFF'
            osa_start_measurement(instrument_OSA);
        end
        if storage_mode == 'AVS'
            osa_start_measurement_with_sweep_averaging(instrument_OSA);
        end

        pt100_teplota=start_temperature_measurement_with_pt100(instrument_U3606);
           
        y_data = osa_get_trace_data(instrument_OSA,active_trace);
    
        x_data=start_wavelength:(span/(sample_points-1)):stop_wavelength;
    
        save_data(meas_timestamp,start_wavelength,stop_wavelength,'SENSORS',attenuator,ecl_power,ecl_wavelength,pt100_teplota,y_data,logfile_name);

        disp("Next measurement at: " + datestr(datetime(next_meas_time,'ConvertFrom','posixtime')) + " Count=" + meas_count);

        if meas_count > 600
            clc
            disp("MEASUREMENT FINISHED ");
            return
        end
        
    end
end

%==========================================================================
%------------------------- OSA WL CALIBRATION -----------------------------
if(MODE == 3)
    osa_cal_source_on(instrument_OSA);
    osa_start_wl_cal(instrument_OSA);
    osa_cal_source_off(instrument_OSA);
end

%==========================================================================
%----------------------- CAL PATH CONTINOUOS ------------------------------
if(MODE == 4)
    
    cal_start_wavelength = 1520;        % [nm]
    cal_stop_wavelength = 1600;         % [nm]
    cal_step = 1;                       % [nm]
    
    disp("CAL PATH START from " +cal_start_wavelength +"nm to "+cal_stop_wavelength+"nm step "+cal_step+"nm")

    meas_period = 3600;  % sek
    next_meas_time = round(posixtime(datetime('now')))+5;    % first meas. after 5 sek.

    logfile_name=append('logCAL',date,'.csv');
    cal_path_create_logfile_header(idn_OSA,instrument_OSA.ResourceName,idn_OSICS,instrument_OSICS.ResourceName,cal_start_wavelength,cal_stop_wavelength,cal_step,resolution,video_bandwith,reference_level,'G.Hencze',logfile_name,meas_period,storage_mode,sweep_average_count,attenuator,ecl_power,2);    

    while true
        
        while true  % wait for next measurement
            time_now = round(posixtime(datetime('now')));
            if time_now == next_meas_time
                break;
            end
        end
        
        meas_timestamp=datestr(datetime('now'));
        next_meas_time = round(posixtime(datetime('now'))) + meas_period;
        
        teplota_pt100=start_temperature_measurement_with_pt100(instrument_U3606);
        teplota_fbg1=start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,10,1);
        teplota_fbg2=start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,10,2);
        teplota_fbg3=start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,10,3);
        
        osics_switch_config(instrument_OSICS,'BAR');
        osa_set_sample_points(instrument_OSA,501);
        osa_set_sweep_average_count(instrument_OSA,1);
        osa_select_storage_mode(instrument_OSA,'A','OFF');
        
        k=0;    
        for actual_wavelength = cal_start_wavelength:cal_step:cal_stop_wavelength

            k=k+1;
            for i=1:3

                disp("---------------------------------------")
                disp("Wavelength= "+actual_wavelength+" nm")
        
                osics_set_ecl_wavelength(instrument_OSICS,actual_wavelength);
    
                osa_set_wavelength_range(instrument_OSA,actual_wavelength-1,actual_wavelength+1);
                
                osa_start_measurement(instrument_OSA);
        
                y_data = osa_get_trace_data(instrument_OSA,'A');
    
                peak = osa_get_peak(instrument_OSA);
                disp("Peak: "+peak(1)+"nm  "+peak(2)+ "dBm")
                
                peak_power=max(y_data);

                if k == 1
                    break
                end
    
                if k > 1
                    odchylka = abs(((cal_path(k-1)-peak_power)/cal_path(k-1))*100);
                    disp("Odchylka: "+odchylka+" %")
                    if odchylka < 0.6
                        break
                    end
                    if odchylka >= 0.6
                        disp("Opakujem meranie")
                    end
                end
            end
            
            cal_path(k)=peak_power;
            
        end
        
        %plot(cal_start_wavelength:cal_step:cal_stop_wavelength,cal_path)
        cal_path_save_data(meas_timestamp,teplota_pt100,teplota_fbg1,teplota_fbg2,teplota_fbg3,cal_path,logfile_name);
        disp("Next measurement at: " + datestr(datetime(next_meas_time,'ConvertFrom','posixtime')));
        %break
    end

end

%==========================================================================
%========================= CALIBRATION ====================================
if(MODE == 5)

    cal_start_wavelength = 1540;        % [nm]
    cal_stop_wavelength = 1560;         % [nm]
    cal_step = 1;                       % [nm]
    
    disp("CALIBRATION " +cal_start_wavelength +"nm to "+cal_stop_wavelength+"nm step "+cal_step+"nm")
    osics_switch_config(instrument_OSICS,'BAR');
    osa_set_sample_points(instrument_OSA,501);
    osa_set_sweep_average_count(instrument_OSA,10);
    osa_select_storage_mode(instrument_OSA,'A','AVS');

    k=0;
    for actual_wavelength = cal_start_wavelength:cal_step:cal_stop_wavelength
        
        k=k+1;

        disp("---------------------------------------")
        disp("Wavelength= "+actual_wavelength+" nm")
        
        osics_set_ecl_wavelength(instrument_OSICS,actual_wavelength);
    
        osa_set_wavelength_range(instrument_OSA,actual_wavelength-1,actual_wavelength+1);
                
        osa_start_measurement_with_sweep_averaging(instrument_OSA);
        
        y_data = osa_get_trace_data(instrument_OSA,'A');
    
        peak = osa_get_peak(instrument_OSA);
        disp("Peak: "+peak(1)+"nm  "+peak(2)+ "dBm")
                
        peak_power=max(y_data);

        cal_path(k)=peak_power;
    end

    x_data=1540:1:1560;
    plot(x_data,cal_path, 'LineWidth',1)
    xlabel('vlnova dlzka [nm]')
    ylabel('vykon [dBm]')

end
%==========================================================================
%------------------------ INSERTION LOSS MEAS -----------------------------
if(MODE == 6)

    meas_start_wavelength = 1540;        % [nm]
    meas_stop_wavelength = 1560;         % [nm]
    meas_step = 1;                       % [nm]
    
    disp("INSERTION LOSS MEAS " +meas_start_wavelength +"nm to "+meas_stop_wavelength+"nm step "+meas_step+"nm")
    osics_switch_config(instrument_OSICS,'BAR');
    osa_set_sample_points(instrument_OSA,501);
    osa_set_sweep_average_count(instrument_OSA,10);
    osa_select_storage_mode(instrument_OSA,'A','AVS');

    k=0;
    for actual_wavelength = meas_start_wavelength:meas_step:meas_stop_wavelength
        
        k=k+1;

        disp("---------------------------------------")
        disp("Wavelength= "+actual_wavelength+" nm")
        
        osics_set_ecl_wavelength(instrument_OSICS,actual_wavelength);
    
        osa_set_wavelength_range(instrument_OSA,actual_wavelength-1,actual_wavelength+1);
                
        osa_start_measurement_with_sweep_averaging(instrument_OSA);
        
        y_data = osa_get_trace_data(instrument_OSA,'A');
    
        peak = osa_get_peak(instrument_OSA);
        disp("Peak: "+peak(1)+"nm  "+peak(2)+ "dBm")
                
        peak_power=max(y_data);

        insertion_loss100(k)=peak_power-cal_path(k);
    end

    x_data=1540:1:1560;
    plot(x_data,insertion_loss, 'LineWidth',1)
    xlabel('vlnova dlzka [nm]')
    ylabel('Insertion loss [dB]')

end

%==========================================================================
if(MODE == 7)
    % temperature measurement
    start_temperature_measurement_with_pt100(instrument_U3606);
    start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,2,1);
    start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,2,2);
    start_temperature_measurement_with_fbg(instrument_OSA,instrument_OSICS,2,3);
end

%============================= FUNCTIONS ==================================
%==========================================================================
%------------------------- TEMPERATURE MEASUREMENT ------------------------
function temperature = start_temperature_measurement_with_fbg(instr_OSA,instr_OSICS,avg_count,sensor_nr)
    
    S1_array = [5.969324E-6 5.973570E-6 6.033297E-6];
    S2_array = [9.096922E-9 8.565797E-9 8.719795E-9];
    lambda_ref_array = [1539.13 1546.04 1553.027];
    cut_level_array = [-65 -65 -65];
    
    S1=S1_array(sensor_nr);
    S2=S2_array(sensor_nr);
    lambda_ref=lambda_ref_array(sensor_nr);
    cut_level_db=cut_level_array(sensor_nr);

    start_wl = round(lambda_ref)-2;
    stop_wl =  round(lambda_ref)+2;
    span = stop_wl - start_wl;
    
    osics_switch_config(instr_OSICS,'CROSS');

    osa_set_wavelength_range(instr_OSA,start_wl,stop_wl);          
    osa_set_sample_points(instr_OSA,1001);  
    osa_set_ref_level(instr_OSA,-50);
    osa_set_scale_div(instr_OSA,3);
    osa_set_sweep_average_count(instr_OSA,avg_count);
    osa_select_storage_mode(instr_OSA,'A','OFF');

    osa_start_measurement(instr_OSA);
    
    y_data=osa_get_trace_data(instr_OSA,'A');

    peak = osa_get_peak(instr_OSA);
    %disp("Peak: "+peak(1)+"nm  "+peak(2)+ "dBm")

    x_data=start_wl:(span/(1001-1)):stop_wl;

    power_mw=10.^(y_data/10);      % convert power dBm to mW

    cut_level_mw=10^(cut_level_db/10);

    for i=1:1001
         if power_mw(i) < cut_level_mw
             power_mw(i)=0;
         end
    end

    sum_cit=0;
    sum_men=0;
    for i=1:1000    % centroid
        sum_cit=sum_cit+(x_data(i)*power_mw(i));
        sum_men=sum_men+power_mw(i);
    end

    center_wavelength=sum_cit/sum_men;
    temperature=22.5-(S1/(2*S2))+sqrt((S1/(2*S2))^2+(1/S2)*log(center_wavelength/lambda_ref));
    disp("Center wavelength: " + center_wavelength + " nm");
    disp("Temperature_fbg[" +sensor_nr+"] = " + temperature + " °C");
end

%--------------------------------------------------------------------------
function temperature_pt100 = start_temperature_measurement_with_pt100(instrument)

    for i=1:3
        writeline(instrument,'MEAS:RES? 100, 0.001');    % meas resistance range 1000 || resolution 1mohm
        response = readline(instrument);   
        odpor_pt100(i)=sscanf(response,'%f');
        writeline(instrument,'*OPC?');
        fscanf(instrument);
    end

    res_average=0;
    for i=1:3
        res_average=res_average+odpor_pt100(i);
    end
    res_average=res_average/3;
    res_average=res_average-0.1;

    R0=100;       % odpor pri 0°C
    tcr=0.00385;  % ppm/K
    temperature_pt100=((res_average/R0)-1)/tcr;
    disp("Temperature_pt100: " + temperature_pt100 + " °C");
end

%==========================================================================
%--------------------------------------------------------------------------
%------------------------ INSTRUMENT CONTROL ------------------------------
%------------------------------- OSA --------------------------------------
function [] = osa_set_wavelength_range(instrument,start_wl,stop_wl)
    
    if start_wl >= stop_wl
        disp("ERROR: START WL >= STOP WL");
        return
    end

    actual_start_wl = writeread(instrument,'STA?');   
    actual_start_wl=sscanf(actual_start_wl,'%f');
    actual_stop_wl = writeread(instrument,'STO?');   
    actual_stop_wl=sscanf(actual_stop_wl,'%f');

    if start_wl >= actual_stop_wl

        command = append('STO ',num2str(stop_wl));
        writeline(instrument,command);    % set stop wavelength first
        writeline(instrument,'*OPC?');
        fscanf(instrument);

        command = append('STA ',num2str(start_wl));
        writeline(instrument,command);    % set start wavelength
        writeline(instrument,'*OPC?');
        fscanf(instrument);

        return
    end

    command = append('STA ',num2str(start_wl));
    writeline(instrument,command);    % set start wavelength first
    writeline(instrument,'*OPC?');
    fscanf(instrument);

    command = append('STO ',num2str(stop_wl));
    writeline(instrument,command);    % set stop wavelength
    writeline(instrument,'*OPC?');
    fscanf(instrument);
end

function [] = osa_set_sample_points(instrument,sample_points)
    command = append('MPT ',int2str(sample_points));
    writeline(instrument,command);       % set sample points
    writeline(instrument,'*OPC?');
    fscanf(instrument);                  % wait for operation complete
end

function [] = osa_set_resolution(instrument,resolution)
    command = append('RES ',num2str(resolution));
    writeline(instrument,command);       % set resolution
    writeline(instrument,'*OPC?');
    fscanf(instrument);                  % wait for operation complete
end

function [] = osa_set_video_bandwith(instrument,bandwith)
    command = append('VBW ',int2str(bandwith));
    writeline(instrument,command);          % set VBW
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
end

function [] = osa_set_ref_level(instrument,ref_level)
    command = append('RLV ',num2str(ref_level));
    writeline(instrument,command);          % set ref level dBm
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
end

function [] = osa_set_scale_div(instrument,scalediv)
    command = append('LOG ',num2str(scalediv));
    writeline(instrument,command);          % set scale div
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
end

function [] = osa_set_sweep_average_count(instrument,count)
    command = append('AVS ',int2str(count));
    writeline(instrument,command);         % set sweep avg count
    writeline(instrument,'*OPC?');
    fscanf(instrument);                    % wait for operation complete
end

function [] = osa_select_storage_mode(instrument,active_trace,storage_mode)
    command = append('SMD ',active_trace,',',storage_mode);
    writeline(instrument,command);     % AVS | MAX | MIN | OFF | OVL
    writeline(instrument,'*OPC?');
    fscanf(instrument);                % wait for operation complete
end

function [] = osa_trace_select(instrument,trace)
    command = append('TSL ',trace);
    writeline(instrument,command);     % TSL A | TSL B | TSL C ...
    writeline(instrument,'*OPC?');
    fscanf(instrument);                % wait for operation complete
end

function [] = osa_set_trace_type(instrument,trace,trace_type)
    command = append('TTP ',trace,',',trace_type);
    writeline(instrument,command);     % BLANK | CAL| FIX | WRITE
    writeline(instrument,'*OPC?');
    fscanf(instrument);                % wait for operation complete
end

function peak = osa_get_peak(instrument)
    
    writeline(instrument,'PKS PEAK');
    writeline(instrument,'*OPC?');
    fscanf(instrument);
    peak_str=writeread(instrument,'TMK?');
    peak=sscanf(peak_str,'%f,%fDBM');
end

function instr_status = osa_check_instrument_status(instrument)
    
    standard_event_register = writeread(instrument,'*ESR?');  
    standard_event_register=sscanf(standard_event_register,'%d');

    error_event_register = writeread(instrument,'ESR3?');  
    error_event_register=sscanf(error_event_register,'%d');

    end_event_register = writeread(instrument,'ESR2?');  
    end_event_register=sscanf(end_event_register,'%d');

    main_status_register = writeread(instrument,'*STB?');  
    main_status_register=sscanf(main_status_register,'%d');

    instr_status=[standard_event_register error_event_register end_event_register main_status_register];
end

function [] = osa_cal_source_on(instrument)
    writeline(instrument,'OPT ON');               
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
    disp("CAL SOURCE ACTIVE");
end

function [] = osa_cal_source_off(instrument)
    writeline(instrument,'OPT OFF');               
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
    disp("CAL SOURCE DISABLED");
end

function [] = osa_start_wl_cal(instrument)
% Executes wavelength calibration when using reference light source and creates wavelength calibration data
    disp("Wavelength calibration start");
    writeline(instrument,'WCAL 2');

    while true
        cal_status = writeread(instrument,'WCAL?');  
        cal_status=sscanf(cal_status,'%d');

        if cal_status == 0
            disp("Ends wavelength calibration");
            break
        end
        if cal_status == 1
            % in progress
        end
        if cal_status == 2
            disp("Terminates wavelength calibration due to lack of optical level");
            break
        end
        if cal_status == 3
            disp("Terminates wavelength calibration due to other abnormal phenomena");
            break
        end
    end
end

function [] = osa_start_measurement(instrument)
    disp("start measurement...please wait");
    writeline(instrument,'SSI');            % start single measurement
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
    disp("measurement finished.");
end

function [] = osa_start_measurement_with_sweep_averaging(instrument)

    disp("start measurement, sweep averaging...please wait");
    writeline(instrument,'*CLS');           % clear status register
    writeline(instrument,'SSI');            % start measurement
    sweep_count=0;

    while true     % querry End Event Status Register
        esr2=writeread(instrument,'ESR2?');   
        esr2=sscanf(esr2,'%d');
        if bitand(esr2 , 0x0A) == 10  % sweep averaging completed
            sweep_count=sweep_count+1;
            disp("Sweep count: "+sweep_count);
            break
        end
        if bitand(esr2 , 0x02) == 2  % sweep completed
            sweep_count=sweep_count+1;
            disp("Sweep count: "+sweep_count);
        end
    end
    
    disp("measurement finished.");
end

function y_data = osa_get_trace_data(instrument,trace)
    instrument.flush();                      % clear all buffers
    command=append('DB',trace,'?');          % DBA? | DBB? | DBC? ...
    writeline(instrument,command);           % query trace data binary
    y_data=readbinblock(instrument,"double");
%   y_data=round(y_data,2);
    writeline(instrument,'*OPC?');
    fscanf(instrument);                      % wait for operation complete
end

%------------------------------- OSICS ------------------------------------
%----------- SWT ----------------------------------------------------------
function [] = osics_switch_config(instrument,value)
    swt_config_cmd = append('CH2:',value); % BAR | CROSS
    writeline(instrument,swt_config_cmd);               
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
end

%----------- OSICS ATN CONTROL --------------------------------------------
function atn = osics_get_atn_value(instrument)
    writeline(instrument,'CH3:ATN?');    % get atn value
    atn_string = readline(instrument);   
    atn=sscanf(atn_string,'CH3:ATN=%f');
end

function [] = osics_set_atn_value(instrument,atn_value)  % set ATN value
    set_atn_cmd = append('CH3:ATN ',num2str(atn_value)); 
    writeline(instrument,set_atn_cmd);  
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
end

%----------- OSICS ECL CONTROL --------------------------------------------
function ecl_power = osics_get_ecl_power(instrument)
    writeline(instrument,'CH1:P?');    % get ecl power
    ecl_pwr_response = readline(instrument);        
    if ecl_pwr_response == "CH1:Disabled"
        ecl_power=99;   % 99 if disabled
        return
    end
    ecl_power=sscanf(ecl_pwr_response,'CH1:P=%f');
end

function [] = osics_set_ecl_power(instrument,power)
    % CH1:P=±xx.xx     [dB]
    command = append('CH1:P=',num2str(power));
    writeline(instrument,command);     % set ecl power
    writeline(instrument,'*OPC?');
    fscanf(instrument);    
end

function ecl_lambda = osics_get_ecl_wavelength(instrument)
    writeline(instrument,'CH1:L?');    % get ecl wavelength [nm]
    ecl_wlngth_string = readline(instrument);   
    ecl_lambda=sscanf(ecl_wlngth_string,'CH1:L=%f');
end

function [] = osics_set_ecl_wavelength(instrument,wavelength)
    command = append('CH1:L=',num2str(wavelength));
    writeline(instrument,command);     % set ecl wavelength
    writeline(instrument,'*OPC?');
    fscanf(instrument);
end

function [] = osics_ecl_enable(instrument)
    writeline(instrument,'CH1:ENABLE');
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % laser ON
end

function [] = osics_ecl_disable(instrument)
    writeline(instrument,'CH1:DISABLE');
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % laser OFF
end

function [] = set_source_voltage(instrument)

end

%==========================================================================
%--------------------------- LOGFILE --------------------------------------
function [] = create_logfile_header(idn_osa,osa_resourcename,idn_osics,osics_resourcename,idn_U3606,U3606_resourcename,start,stop,samplepoints,resolution,vbw,ref_level,operator,logfile_name,meas_period,sweep_mode,sweep_avg_count,atn_value,ecl_power,ecl_wavelength,span)
    fileID = fopen(logfile_name,'a');
    fprintf(fileID,'Logfile created at; %s\n',datestr(datetime('now')));
    fprintf(fileID,'OSA Instrument IDN; %s\n',idn_osa);
    fprintf(fileID,'OSA ResourceName; %s\n',osa_resourcename);
    fprintf(fileID,'OSICS Instrument IDN; %s\n',idn_osics);
    fprintf(fileID,'OSICS ResourceName; %s\n',osics_resourcename);
    fprintf(fileID,'U3606 Instrument IDN; %s\n',idn_U3606);
    fprintf(fileID,'U3606 ResourceName; %s\n',U3606_resourcename);
    fprintf(fileID,'Start wavelength [nm]; %s\n',num2str(start));
    fprintf(fileID,'Stop wavelength [nm]; %s\n',num2str(stop));
    fprintf(fileID,'Span [nm]; %s\n',num2str(span));
    fprintf(fileID,'Sample points; %s\n',int2str(samplepoints));
    fprintf(fileID,'Resolution [nm]; %s\n',num2str(resolution));
    fprintf(fileID,'Video bandwith [Hz]; %s\n',num2str(vbw));
    fprintf(fileID,'Ref.level [dBm]; %s\n',num2str(ref_level));
    fprintf(fileID,'Sweep average mode; %s\n',sweep_mode);
    fprintf(fileID,'Sweep average count; %s\n',int2str(sweep_avg_count));
    fprintf(fileID,'Attenuation [dB]; %s\n',num2str(atn_value));
    fprintf(fileID,'ECL power [dBm]; %s\n',num2str(ecl_power));
    fprintf(fileID,'ECL wavelength [nm]; %s\n',num2str(ecl_wavelength));
    fprintf(fileID,'Meas period [min]; %s\n',num2str(meas_period/60));
    fprintf(fileID,'Operator; %s\n',operator);
    fprintf(fileID,'info;\n');
    fprintf(fileID,'\nTimestamp;start;stop;Switch;ATN;ECL power;ECL wavelength;Pt100 teplota;');
    fprintf(fileID,'%6.6f;',start:((stop-start)/(samplepoints-1)):stop);
    fprintf(fileID,'\n');
    fclose(fileID);
end

function [] = save_data(meas_timestamp,start,stop,switch_status,attenuator,ecl_power,ecl_wavelength,pt100_teplota,y_data,logfile_name)
    fileID=fopen(logfile_name,'a');     % Append
    fprintf(fileID,'%s;%6.6f;%6.6f;%s;%6.6f;%6.6f;%6.6f;%6.6f;%6.6f;',meas_timestamp,start,stop,switch_status,attenuator,ecl_power,ecl_wavelength,pt100_teplota,y_data);
    fprintf(fileID,'\n');
    fclose(fileID);
end

function [] = cal_path_create_logfile_header(idn_osa,osa_resourcename,idn_osics,osics_resourcename,start,stop,step,resolution,vbw,ref_level,operator,logfile_name,meas_period,sweep_mode,sweep_avg_count,atn_value,ecl_power,span)
    fileID = fopen(logfile_name,'a');
    fprintf(fileID,'Logfile created at; %s\n',datestr(datetime('now')));
    fprintf(fileID,'OSA Instrument ID; %s\n',idn_osa);
    fprintf(fileID,'OSA ResourceName; %s\n',osa_resourcename);
    fprintf(fileID,'OSICS Instrument ID; %s\n',idn_osics);
    fprintf(fileID,'OSICS ResourceName; %s\n',osics_resourcename);
    fprintf(fileID,'CAL Start wavelength [nm]; %s\n',num2str(start));
    fprintf(fileID,'CAL Stop wavelength [nm]; %s\n',num2str(stop));
    fprintf(fileID,'OSA Span [nm]; %s\n',num2str(span));
    fprintf(fileID,'CAL Step [nm]; %s\n',int2str(step));
    fprintf(fileID,'Resolution [nm]; %s\n',num2str(resolution));
    fprintf(fileID,'Video bandwith [Hz]; %s\n',num2str(vbw));
    fprintf(fileID,'Ref.level [dBm]; %s\n',num2str(ref_level));
    fprintf(fileID,'Sweep average mode; %s\n',sweep_mode);
    fprintf(fileID,'Sweep average count; %s\n',int2str(sweep_avg_count));
    fprintf(fileID,'Attenuation [dB]; %s\n',num2str(atn_value));
    fprintf(fileID,'ECL power [dBm]; %s\n',num2str(ecl_power));
    fprintf(fileID,'Meas period [min]; %s\n',num2str(meas_period/60));
    fprintf(fileID,'Operator; %s\n',operator);
    fprintf(fileID,'info;\n');
    fprintf(fileID,'\nTimestamp;Teplota pt100;Teplota FBG1;teplota FBG2;Teplota FBG3;');
    fprintf(fileID,'%6.6f;',start:step:stop);
    fprintf(fileID,'\n');
    fclose(fileID);
end

function [] = cal_path_save_data(meas_timestamp,teplota1,teplota2,teplota3,teplota4,y_data,logfile_name)
    fileID=fopen(logfile_name,'a');     % Append
    fprintf(fileID,'%s;%6.6f;%6.6f;%6.6f;%6.6f;%6.6f;',meas_timestamp,teplota1,teplota2,teplota3,teplota4,y_data);
    fprintf(fileID,'\n');
    fclose(fileID);
end



