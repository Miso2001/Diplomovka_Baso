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