tic; 

% refer to latex document for more information about this data
option_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\option_raw_data.csv");
fprintf('Number of contracts in raw data : %d\n', height(option_data));

% we want option data with symbol 'SPX' and data on each Wednesday 
spx_condition = contains(option_data.symbol, 'SPX') & ...
    ~contains(option_data.symbol, 'SPXW'); 
weekday_condition = weekday(option_data.date)==4;
spx_data = option_data(spx_condition & weekday_condition, :); % add back spx_condition 
fprintf('Number of contracts left after selecting data with SPX ticker on Wednesday : %d\n',...
    height(spx_data));

% screening conditions 
moneyness_condition = (strcmp(spx_data.cp_flag, 'C') & spx_data.delta>0.1 & spx_data.delta <=0.55) |...
    (strcmp(spx_data.cp_flag, 'P') & spx_data.delta>=-0.55 & spx_data.delta < -0.1);
spx_data.mid_quote = (spx_data.best_bid + spx_data.best_offer) / 2; 
mid_quote_condition = spx_data.mid_quote > 3/8;
volatility_condition = (spx_data.impl_volatility > 0.05) & (spx_data.impl_volatility < 0.90);
liquidity_condition = (spx_data.volume > 0) & (spx_data.open_interest > 0);

% data screening 
weekly_data = spx_data(moneyness_condition & mid_quote_condition...
    & volatility_condition & liquidity_condition, :);

fprintf('Number of contracts left after applying basic screening criteria : %d\n',...
    height(weekly_data)); 

% no-arbitrage lower bound (option data has dividend information in it)
% https://fred.stlouisfed.org/series/DTB3
index_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");
weekly_data = innerjoin(weekly_data, index_data, 'LeftKeys', 'date', 'RightKeys', 'caldt'); 
weekly_data = innerjoin(weekly_data, rf_data, 'LeftKeys', 'date', 'RightKeys', 'observation_date');
weekly_data.DTB3 = weekly_data.DTB3 / 100; 

weekly_data.time_to_maturity = days(weekly_data.exdate - weekly_data.date) / 365; 
call_lower_bound = max(0, weekly_data.spindx - ...
    exp(-weekly_data.DTB3 .* weekly_data.time_to_maturity) .* weekly_data.strike_price/1000);
put_lower_bound = max(0, exp(-weekly_data.DTB3 .* weekly_data.time_to_maturity) .* ...
    weekly_data.strike_price/1000 - weekly_data.spindx); 

no_arbitrage_condition = ...
    (strcmp(weekly_data.cp_flag, 'C') & weekly_data.mid_quote >= call_lower_bound) |...
    (strcmp(weekly_data.cp_flag, 'P') & weekly_data.mid_quote >= put_lower_bound);

weekly_data2 = weekly_data(no_arbitrage_condition, :); 

% maximum vertical spread condition 
vertical_spread_condition = true(height(weekly_data2), 1); % mark which rows of data qualify for condition
grouped_data = findgroups(weekly_data2.date, weekly_data2.cp_flag, weekly_data2.exdate); 

for i = 1:max(grouped_data)
    group_idx = (grouped_data == i); 
    group_data = weekly_data2(group_idx, :); 
    [~, sort_idx] = sort(group_data.strike_price); 
    group_data = group_data(sort_idx, :); 

    price_diff = diff(group_data.mid_quote);
    strike_diff = diff(group_data.strike_price); 

    if strcmp(group_data.cp_flag{1}, 'C')
        valid_spread = price_diff <= strike_diff; 
    else
        valid_spread = price_diff <= strike_diff; 
    end 

    valid_rows = [true; valid_spread]; 
    sorted_indices = find(group_idx); 
    vertical_spread_condition(sorted_indices(sort_idx)) = valid_rows; 
end 
weekly_data2 = weekly_data2(vertical_spread_condition, :); 

fprintf('Number of contracts left after applying arbitrage conditions : %d\n',...
    height(weekly_data2));

% to ensure good liquidity, we select option with 14-45 days to maturity
weekly_data2.time_to_maturity_days = days(weekly_data2.exdate - weekly_data2.date);
maturity_condition = (weekly_data2.time_to_maturity_days >= 14) & ...
    (weekly_data2.time_to_maturity_days <= 45); 

weekly_data3 = weekly_data2(maturity_condition, :); 

% select the data with days to maturity closest to 30 days 
target_days = [30];
unique_dates = unique(weekly_data3.date);
weekly_data4 = table();

for i = 1:length(unique_dates)
    current_date = unique_dates(i);
    date_group = weekly_data3(weekly_data3.date==current_date, :);
    for j = 1:length(target_days)
        target = target_days(j);
        min_diff = min(abs(date_group.time_to_maturity_days - target));
        closest_indices = find(abs(date_group.time_to_maturity_days - target)==min_diff);

        if numel(closest_indices) > 1
             max_maturity = max(date_group.time_to_maturity_days(closest_indices));
             closest_indices = closest_indices(date_group.time_to_maturity_days(closest_indices) == max_maturity);
        end 

        closest_rows = date_group(closest_indices, :);
        weekly_data4 = [weekly_data4; closest_rows];
    end
end 

fprintf('Number of contracts left after selecting specific days to maturity : %d\n',...
    height(weekly_data4)); 

% screening the data to make sure not too much observations in a date 
num_bins = 5; % can set num_bins = 10 for more stable estimation  
call_delta_bins = linspace(0, 0.55, num_bins + 1); 
put_delta_bins = linspace(-0.55, 0, num_bins + 1); 
final_filtered_data = table(); 
unique_dates = unique(weekly_data4.date); 

for i = 1:length(unique_dates)
    current_date = unique_dates(i); 
    date_group = weekly_data4(weekly_data4.date == current_date, :); 

    call_data = date_group(strcmp(date_group.cp_flag, 'C'), :);
    put_data = date_group(strcmp(date_group.cp_flag, 'P'), :); 

    for j = 1:num_bins
        lower_bound = call_delta_bins(j); 
        upper_bound = call_delta_bins(j + 1); 
        target_mid = (lower_bound + upper_bound) / 2; 

        bin_data = call_data(call_data.delta >= lower_bound & call_data.delta < upper_bound, :);
        if ~isempty(bin_data)
            [~, closest_idx] = min(abs(bin_data.delta - target_mid)); 
            final_filtered_data = [final_filtered_data; bin_data(closest_idx, :)];
        end 
    end 

    for j = 1:num_bins
        lower_bound = put_delta_bins(j);
        upper_bound = put_delta_bins(j + 1); 
        target_mid = (lower_bound + upper_bound) / 2; 

        bin_data = put_data(put_data.delta >= lower_bound & put_data.delta < upper_bound, :);
        if ~isempty(bin_data)
            [~, closest_idx] = min(abs(bin_data.delta - target_mid));
            final_filtered_data = [final_filtered_data; bin_data(closest_idx, :)];
        end 
    end 
end 

fprintf('Number of contracts left after the whole process : %d\n', height(final_filtered_data));

% store final_filtered_data 
output_file = "C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data2.csv";
writetable(final_filtered_data, output_file); 
disp(['Data saved to ', output_file]);

elapsed_time = toc; 
fprintf('Run time: %.2f second\n', elapsed_time);


