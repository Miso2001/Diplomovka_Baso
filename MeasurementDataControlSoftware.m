
clc;
clear;
%-------------------------- PARAMETERS OF OSA --------------------------------

start_wavelength=1500;            % [nm] Rozsah: <600..1750> nm
stop_wavelength=1550.0;             % [nm] Rozsah: <600..1750> nm
sample_points =10001;                % Počet bodov: 51 | 101 | ... | 10001 | ...
resolution = 0.07;                  % [nm] Rozlišovacia šírka pásma: 0.07 | 0.1 | 0.2 | 0.5 | 1.0
video_bandwith= 1000;               % [Hz] Video šírka pásma: 10 | 100 | ... | 1000000
reference_level = -20;              % [dBm] Referenčná úroveň: <-90...30>
log_scale_div =5;                   % [dB/div] Vertikálna stupnica: <0.1...10>
sweep_average_count = 20;            % Počet spriemerovaní: <1...1000>
storage_mode = 'OFF';               % Režim ukladania stopy: AVS | OFF (AVS = Average)
active_trace = 'A';                 % Aktívna stopa: A...J
trace_type = 'WRITE';               % Typ stopy: BLANK|CALC|FIX|WRITE

span = stop_wavelength - start_wavelength; % Vypočítaný span

%-------------------------- COMMUNICATION WITH OSA -----------------------------

instrument_OSA = visadev("GPIB0::1::INSTR");
instrument_OSA.Timeout=1000;        % Nastavenie dlhého timeoutu (100 sek)
idn_OSA=writeread(instrument_OSA,"*IDN?");
disp(['OSA pripojená: ', idn_OSA]);

instrument_OSICS = visadev("GPIB0::20::INSTR");
instrument_OSICS.Timeout=20;       % timeout 20 sek for OSICS
idn_OSICS=writeread(instrument_OSICS,"*IDN?");


%-------------------------- INIT OSA --------------------------------------

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



%-------------------------- MEASUREMENT --------------------------------------
 tic
    if storage_mode == 'OFF'
        osa_start_measurement(instrument_OSA);
    end
    if storage_mode == 'AVS'
        osa_start_measurement_with_sweep_averaging(instrument_OSA);
    end
    toc

    y_data = osa_get_trace_data(instrument_OSA,active_trace);
    
    x_data=start_wavelength:(span/(sample_points-1)):stop_wavelength;
        
    plot(x_data,y_data, 'LineWidth',1)
    %yline(-64,'--r','Cut level')
    xlabel('vlnova dlzka [nm]')
    ylabel('vykon [dBm]')

%-------------------------- OSA CONTROL FUNCTIONS --------------------------------

function [] = osa_set_wavelength_range(instrument, start_wl, stop_wl)
    
    if start_wl >= stop_wl
        disp("ERROR: START WL >= STOP WL");
        return
    end

    % 1. Načítanie aktuálnych nastavení
    actual_start_wl_str = writeread(instrument, 'STA?');   
    actual_start_wl = sscanf(actual_start_wl_str, '%f');
    actual_stop_wl_str = writeread(instrument, 'STO?');   
    actual_stop_wl = sscanf(actual_stop_wl_str, '%f');
    
    % 2. Logika poradia nastavenia
    if start_wl >= actual_stop_wl
   
        command_stop = append('STO ', num2str(stop_wl));
        writeline(instrument, command_stop);
        writeline(instrument, '*OPC?'); % Čakáme na dokončenie operácie
        fscanf(instrument);

        command_start = append('STA ', num2str(start_wl));
        writeline(instrument, command_start);
        writeline(instrument, '*OPC?');
        fscanf(instrument);
        return
    end

    command_start = append('STA ', num2str(start_wl));
    writeline(instrument, command_start);
    writeline(instrument, '*OPC?');
    fscanf(instrument);

    command_stop = append('STO ', num2str(stop_wl));
    writeline(instrument, command_stop);
    writeline(instrument, '*OPC?');
    fscanf(instrument);

    disp(['OSA Wavelength Range set to: ', num2str(start_wl), 'nm - ', num2str(stop_wl), 'nm']);
end

function [] = osa_set_sample_points(instrument, sample_points)
    command = append('MPT ', int2str(sample_points)); % MPT = Measurement Points
    writeline(instrument, command);
    writeline(instrument, '*OPC?'); 
    fscanf(instrument);             
end

function [] = osa_set_resolution(instrument, resolution)
    command = append('RES ', num2str(resolution));
    writeline(instrument, command);
    writeline(instrument, '*OPC?');
    fscanf(instrument);
end

function [] = osa_set_video_bandwith(instrument, bandwith)
    command = append('VBW ', int2str(bandwith)); 
    writeline(instrument, command);          
    writeline(instrument, '*OPC?');
    fscanf(instrument);                     
    disp(['OSA Video Bandwidth set to: ', int2str(bandwith), ' Hz']);
end

function [] = osa_set_ref_level(instrument, ref_level)
    command = append('RLV ', num2str(ref_level));
    writeline(instrument, command);         
    writeline(instrument, '*OPC?');
    fscanf(instrument);                     
    disp(['OSA Reference Level set to: ', num2str(ref_level), ' dBm']);
end

function [] = osa_set_scale_div(instrument, scalediv)
    command = append('LOG ', num2str(scalediv)); 
    writeline(instrument, command);         
    writeline(instrument, '*OPC?');
    fscanf(instrument);                     
    disp(['OSA Log Scale Division set to: ', num2str(scalediv), ' dB/div']);
end

function [] = osa_set_sweep_average_count(instrument, count)
    command = append('AVS ', int2str(count));
    writeline(instrument, command);         
    writeline(instrument, '*OPC?');
    fscanf(instrument);                    
    disp(['OSA Sweep Average Count set to: ', int2str(count)]);
end

function [] = osa_select_storage_mode(instrument, active_trace, storage_mode)
    % storage_mode: AVS | MAX | MIN | OFF | OVL
    command = append('SMD ', active_trace, ',', storage_mode); 
    writeline(instrument, command);     
    writeline(instrument, '*OPC?');
    fscanf(instrument);                
    disp(['OSA Trace ', active_trace, ' Storage Mode set to: ', storage_mode]);
end

function [] = osa_trace_select(instrument, trace)
    command = append('TSL ', trace); 
    writeline(instrument, command);     
    writeline(instrument, '*OPC?');
    fscanf(instrument);               
    disp(['OSA Active Trace set to: ', trace]);
end

function [] = osa_set_trace_type(instrument, trace, trace_type)
    % trace_type: BLANK | CAL| FIX | WRITE
    command = append('TTP ', trace, ',', trace_type);
    writeline(instrument, command);     
    writeline(instrument, '*OPC?');
    fscanf(instrument);               
    disp(['OSA Trace ', trace, ' Type set to: ', trace_type]);
end   

function [] = osa_start_measurement(instrument)
    disp("start measurement...please wait");
    writeline(instrument,'SSI');            % start single measurement
    writeline(instrument,'*OPC?');
    fscanf(instrument);                     % wait for operation complete
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
%--------------------------------- SAVING DATA -----------------------------------

function [] = save_osa_settings(logfile_name, start_wl, stop_wl, resolution, ref_level, sweep_avg_count)
    fileID = fopen(logfile_name, 'w'); 
    
    if fileID == -1
        error('Nepodarilo sa otvoriť súbor %s', logfile_name);
    end
    
    fprintf(fileID, '--- OSA Configuration Settings ---\n');
  
    fprintf(fileID, 'Date and Time: %s\n\n', string(datetime('now'), 'yyyy-MM-dd HH:mm:ss'));
    
    fprintf(fileID, 'Start Wavelength [nm]: %s\n', num2str(start_wl));
    fprintf(fileID, 'Stop Wavelength [nm]: %s\n', num2str(stop_wl));
    fprintf(fileID, 'Resolution [nm]: %s\n', num2str(resolution));
    fprintf(fileID, 'Reference Level [dBm]: %s\n', num2str(ref_level));
    fprintf(fileID, 'Sweep Average Count: %d\n', sweep_avg_count); 
    
    fclose(fileID);
    disp(['Nastavenia uložené do: ', logfile_name]);
end

function [] = save_measurement_data(filename, x_data, y_data)
    fileID = fopen(filename, 'w'); 
    if fileID == -1
        error('Nepodarilo sa otvoriť súbor %s', filename);
    end
    
    fprintf(fileID, 'Timestamp: %s\n', string(datetime('now'), 'yyyy-MM-dd HH:mm:ss.FFF'));
    fprintf(fileID, 'Wavelength [nm],Power [dBm]\n');
    
    if length(x_data) ~= length(y_data)
        error('Polia vlnovej dĺžky a výkonu nemajú rovnakú dĺžku.');
    end
    
    data_matrix = [x_data(:), y_data(:)]'; 
    fprintf(fileID, '%6.6f,%6.6f\n', data_matrix);
    
    fclose(fileID);
    disp(['Namerané dáta uložené do: ', filename]);

end
