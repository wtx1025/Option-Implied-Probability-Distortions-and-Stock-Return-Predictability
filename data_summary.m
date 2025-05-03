%{
option_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\option_raw_data.csv");
spx_condition = contains(option_data.symbol, 'SPX') & ...
    ~contains(option_data.symbol, 'SPXW'); 
weekday_condition = weekday(option_data.date) == 4;
spx_data = option_data(spx_condition & weekday_condition, :);
raw_dates = unique(spx_data.date);
%}

data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data2.csv");
final_dates = unique(data.date);
data_counts = groupcounts(data.date); 

% find missing dates after data screening 
%{
missing_dates = setdiff(raw_dates, final_dates);
fprintf('Number of missing dates: %d\n', length(missing_dates));
disp('Missing dates:');
disp(missing_dates);
%}

% Distribution of Observation Counts per Date 
figure; 
histogram(data_counts, 'BinWidth', 1); 
xlabel('Number of Observation per Date'); 
ylabel('Frequency');
title('Distribution of Observation Counts per Date');
grid on; 

% summary table 
data.moneyness = log((data.strike_price/1000) ./ data.spindx);
moneyness_bins = [-0.5 -0.05, -0.025, 0, 0.025, 0.05, 0.5];
num_bins = length(moneyness_bins) - 1; 

interval_stats = table();
interval_stats.Interval = strings(num_bins, 1);
interval_stats.Count = zeros(num_bins, 1);
interval_stats.IV_Mean = zeros(num_bins, 1);
interval_stats.IV_Max = zeros(num_bins, 1);
interval_stats.IV_Min = zeros(num_bins, 1);
interval_stats.Volume_Mean = zeros(num_bins, 1);
interval_stats.OpenInterest_Mean = zeros(num_bins, 1);

for i = 1:num_bins
    lower_bound = moneyness_bins(i);
    upper_bound = moneyness_bins(i + 1);
    
    bin_data = data(data.moneyness >= lower_bound & ...
                                   data.moneyness < upper_bound, :);
    
    interval_stats.Interval(i) = sprintf("[%.2f, %.2f)", lower_bound, upper_bound);
    interval_stats.Count(i) = height(bin_data);
    
    if ~isempty(bin_data)
        interval_stats.IV_Mean(i) = mean(bin_data.impl_volatility);
        interval_stats.IV_Max(i) = max(bin_data.impl_volatility);
        interval_stats.IV_Min(i) = min(bin_data.impl_volatility);
        interval_stats.Volume_Mean(i) = mean(bin_data.volume);
        interval_stats.OpenInterest_Mean(i) = mean(bin_data.open_interest);
    else
        interval_stats.IV_Mean(i) = NaN;
        interval_stats.IV_Max(i) = NaN;
        interval_stats.IV_Min(i) = NaN;
        interval_stats.Volume_Mean(i) = NaN;
        interval_stats.OpenInterest_Mean(i) = NaN;
    end
end

interval_stats.Interval(num_bins + 1) = "Overall";
interval_stats.Count(num_bins + 1) = height(data);
interval_stats.IV_Mean(num_bins + 1) = mean(data.impl_volatility, 'omitnan');
interval_stats.IV_Max(num_bins + 1) = max(data.impl_volatility);
interval_stats.IV_Min(num_bins + 1) = min(data.impl_volatility);
interval_stats.Volume_Mean(num_bins + 1) = mean(data.volume, 'omitnan');
interval_stats.OpenInterest_Mean(num_bins + 1) = mean(data.open_interest, 'omitnan'); 

disp('Interval Statistics:');
disp(interval_stats);



