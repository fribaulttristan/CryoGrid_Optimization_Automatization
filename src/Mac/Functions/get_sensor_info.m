function [final_name, sensor_info] = get_sensor_info(sensor_name, file, forcing_folder, dt)
% get_sensor_info : Retrieves sensor information from an Excel file.
%
% INPUT :
%   - sensor_name : name to search in the "sensor name" column
%
% OUTPUT :
%   - final_name : actual name found (from 'sensor name' or 'ID')
%   - sensor_info : structure containing sensor info (coordinates, slope, depth...)

    % Read the full table
    T = readtable(file, 'VariableNamingRule', 'preserve');

    % Check required columns
    required_columns = ["ID", "sensor name", "x", "y", "altitude (m)", ...
        "orientation (°)", "snow", "slope", "Depth (m)", ...
        "first measurement date", "last measurement date", "Mean Albedo", "Standard Deviation"];

    if ~all(ismember(required_columns, string(T.Properties.VariableNames)))
        error('The Excel file does not contain all required columns.');
    end

    % Search in "sensor name"
    sensor_names_str = string(cellfun(@(c) strtrim(c), T.("sensor name"), 'UniformOutput', false));
    idx = find(strcmpi(sensor_names_str, string(sensor_name)));

    % If not found, or cell empty / contains '?', search in ID
    if isempty(idx) || any(ismissing(T.("sensor name")(idx))) || any(strcmp(strtrim(string(T.("sensor name")(idx))), '?'))
        idx = find(strcmpi(strtrim(string(T.ID)), sensor_name));
    end

    if isempty(idx)
        error('❌ Sensor "%s" not found in "sensor name" or "ID" columns.', sensor_name);
    end

    % Use the first found
    row = idx(1);

    % Actual name used
    if ismissing(T.("sensor name")(row)) || contains(T.("sensor name"){row}, '?')
        final_name = string(T.ID(row));
    else
        final_name = string(T.("sensor name"){row});
    end

    % Extract values into a structure
    sensor_info.longitude    = T.x(row);
    sensor_info.latitude     = T.y(row);
    sensor_info.altitude     = T.("altitude (m)")(row);
    sensor_info.aspect       = T.("orientation (°)")(row);
    sensor_info.slope_angle  = T.slope(row);
    sensor_info.sensor_depth = T.("Depth (m)")(row);
    sensor_info.start_time   = T.("first measurement date")(row);
    sensor_info.end_time     = T.("last measurement date")(row);
    sensor_info.Mean_Albedo = T.("Mean Albedo")(row);
    sensor_info.Standard_Deviation = T.("Standard Deviation")(row);


    % Add additional elevations
    sensor_info.upper_elevation = sensor_info.altitude + 2;
    sensor_info.lower_elevation = sensor_info.altitude - 5;

    % Add sky view factor
    sensor_info.skyview_factor = 0.5 * (1 + cos(pi/180 * sensor_info.slope_angle));

    % Add recording interval (years)
    sensor_info.save_interval = (year(sensor_info.end_time) - year(sensor_info.start_time)) + 1;

    % Add forcing data file
    forcing_file_found = find_forcing_file(forcing_folder, sensor_name);
    sensor_info.filename = forcing_file_found;

    % Truncate end date if it exceeds SAFRAN data
    max_safran_date = get_last_forcing_date(forcing_file_found);
    if sensor_info.end_time > max_safran_date
        warning("⚠️  Sensor '%s' end date truncated to %s (exceeds SAFRAN data).", sensor_name, max_safran_date);
        sensor_info.end_time = max_safran_date;
    end

    % Add step time
    sensor_info.output_timestep = dt;

    % Add forcing path
    sensor_info.forcing_path = fullfile(forcing_folder, '/');
end
