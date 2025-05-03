% Read data (replace with your actual file path)
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");

% Ensure the date column is in datetime format
sp_data.Date = datetime(sp_data.caldt);

% Filter data to only include entries after 2010/5/31
sp_data = sp_data(sp_data.Date > datetime(2010, 5, 31), :);

% Sort data by date (if not already sorted)
sp_data = sortrows(sp_data, 'Date');

% Extract year and month
sp_data.YearMonth = year(sp_data.Date) * 100 + month(sp_data.Date);

% Calculate monthly returns
monthly_returns = varfun(@(x) (x(end) / x(1)), sp_data, ...
    'InputVariables', 'spindx', ...
    'GroupingVariables', 'YearMonth', ...
    'OutputFormat', 'table');

% Rename the column for clarity
monthly_returns.Properties.VariableNames{'Fun_spindx'} = 'MonthlyReturn';

% Plot the distribution of monthly returns
figure;
histogram(monthly_returns.MonthlyReturn, 30, 'Normalization', 'pdf');
title('Distribution of S&P 500 Monthly Returns');
xlabel('Monthly Return');
ylabel('Probability Density');
grid on;

% Optional: Print summary statistics
fprintf('Mean Monthly Return: %.4f\n', mean(monthly_returns.MonthlyReturn));
fprintf('Standard Deviation of Monthly Returns: %.4f\n', std(monthly_returns.MonthlyReturn));

% Check for skewness and kurtosis
skewness_value = skewness(monthly_returns.MonthlyReturn);
kurtosis_value = kurtosis(monthly_returns.MonthlyReturn);

fprintf('Skewness: %.4f\n', skewness_value);
fprintf('Kurtosis: %.4f\n', kurtosis_value);

% Interpretation of results
if skewness_value > 0
    fprintf('The distribution is positively skewed.\n');
elseif skewness_value < 0
    fprintf('The distribution is negatively skewed.\n');
else
    fprintf('The distribution is symmetric.\n');
end

if kurtosis_value > 3
    fprintf('The distribution has heavy tails (leptokurtic).\n');
elseif kurtosis_value < 3
    fprintf('The distribution has light tails (platykurtic).\n');
else
    fprintf('The distribution has normal kurtosis (mesokurtic).\n');
end


