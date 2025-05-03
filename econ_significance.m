clear;

%% This codes test the economic significance of PWI by constrcuting investment strategy
pwi_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates1.csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
sp_data.DailyReturn = [NaN; diff(log(sp_data.spindx))];

returns = sp_data.DailyReturn;
rolling_window = 1200; 
rolling_std = movstd(returns, rolling_window, 'Endpoints', 'discard');
rolling_std = [NaN(rolling_window-1, 1); rolling_std]; 
sp_data.RollingStd = rolling_std;

sp_data.YearMonth = dateshift(sp_data.caldt, 'start', 'month');
[~, lastDayIdx] = unique(sp_data.YearMonth, 'last');
monthlyLastData = sp_data(lastDayIdx, :);
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
monthlyLastData = monthlyLastData(monthlyLastData.caldt >= startDate & monthlyLastData.caldt <= endDate, :);

rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");
rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.DTB3 = monthlyLastData.DTB3 / (100 * 12);
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3; 

% Return prediction 
predictedReturn = NaN(height(monthlyLastData), 1);
predictedReturn2 = NaN(height(monthlyLastData), 1); % use this month return as prediction 
n = 36;
for t = n:height(monthlyLastData)-1
    X = pwi_data.Alpha(1:t-1);
    Y = monthlyLastData.MonthlyReturn(2:t);
    X_mean = mean(X, 'omitnan');
    X_std = std(X, 'omitnan');
    X_standardized = (X - X_mean) / X_std;
    X_with_intercept = [ones(size(X_standardized)), X_standardized];
    b = regress(Y, X_with_intercept);
    Alpha_t = (pwi_data.Alpha(t) - X_mean) / X_std;
    intercept = b(1);
    if b(2)<0
        slope = 0;
    else
        slope = b(2);
    end
    predictedReturn(t) = intercept + slope * Alpha_t;
    predictedReturn2(t) = mean(monthlyLastData.MonthlyReturn(1:t), 'omitnan'); 
    %predictedReturn2(t) = monthlyLastData.MonthlyReturn(t); 
end 

monthlyLastData.PredictedReturn = predictedReturn;
monthlyLastData.PredictedReturn2 = predictedReturn2; 
gamma = 1;  
monthlyLastData.weight = 1/gamma * (monthlyLastData.PredictedReturn - monthlyLastData.DTB3)...
    ./ ((monthlyLastData.RollingStd) * sqrt(20)) .^ 2; 
monthlyLastData.weight2 = 1/gamma * (monthlyLastData.PredictedReturn2 - monthlyLastData.DTB3)...
    ./ ((monthlyLastData.RollingStd) * sqrt(20)) .^ 2; 

valid_weights = ~isnan(monthlyLastData.weight);
monthlyLastData.weight(valid_weights) = max(-0.5, min(1.5, monthlyLastData.weight(valid_weights)));
valid_weights2 = ~isnan(monthlyLastData.weight2);
monthlyLastData.weight2(valid_weights2) = max(-0.5, min(1.5, monthlyLastData.weight2(valid_weights2)));

shifted_weight = [NaN; monthlyLastData.weight(1:end-1)];
shifted_weight2 = [NaN; monthlyLastData.weight2(1:end-1)];

monthlyLastData.InvestmentReturn = shifted_weight .* monthlyLastData.MonthlyReturn +...
    (1 - shifted_weight) .* monthlyLastData.DTB3; 
monthlyLastData.BenchmarkReturn2 = shifted_weight2 .* monthlyLastData.MonthlyReturn +...
    (1 - shifted_weight2) .* monthlyLastData.DTB3;

total_investment_excess_return = monthlyLastData.InvestmentReturn - monthlyLastData.DTB3;
total_benchmark_excess_return = monthlyLastData.MonthlyReturn(37:end) - monthlyLastData.DTB3(37:end);
total_benchmark_excess_return2 = monthlyLastData.BenchmarkReturn2 - monthlyLastData.DTB3;
investment_mean_excess = mean(total_investment_excess_return, 'omitnan');
benchmark_mean_excess = mean(total_benchmark_excess_return, 'omitnan');
benchmark_mean_excess2 = mean(total_benchmark_excess_return2, 'omitnan');
investment_std_excess = std(total_investment_excess_return, 'omitnan');
benchmark_std_excess = std(total_benchmark_excess_return, 'omitnan');
benchmark_std_excess2 = std(total_benchmark_excess_return2, 'omitnan');
total_investment_sharpe = investment_mean_excess / investment_std_excess;
total_benchmark_sharpe = benchmark_mean_excess / benchmark_std_excess;
total_benchmark_sharpe2 = benchmark_mean_excess2 / benchmark_std_excess2;
average_weight = mean(monthlyLastData.weight, 'omitnan');

fprintf('Average Investment Excess Return: %.6f\n', investment_mean_excess);
fprintf('Average Benchmark Excess Return (BH): %.6f\n', benchmark_mean_excess);
fprintf('Average Benchmark Excess Return (MA): %.6f\n', benchmark_mean_excess2);
fprintf('Total Investment Sharpe Ratio: %.6f\n', total_investment_sharpe * 12/sqrt(12));
fprintf('Total Benchmark Sharpe Ratio (BH): %.6f\n', total_benchmark_sharpe * 12/sqrt(12));
fprintf('Total Benchmark Sharpe Ratio (MA): %.6f\n', total_benchmark_sharpe2 * 12/sqrt(12));
fprintf('Average weight: %.2f\n', average_weight);

% Certainty equivalent return (in percentage and annualized)
investmentCER = investment_mean_excess * 12 - 0.5 * gamma * (investment_std_excess * sqrt(12)) ^ 2;
benchmarkCER = benchmark_mean_excess * 12 - 0.5 * gamma * (benchmark_std_excess * sqrt(12)) ^ 2;
benchmarkCER2 = benchmark_mean_excess2 * 12 - 0.5 * gamma * (benchmark_std_excess2 * sqrt(12)) ^ 2;
fprintf('Investment CER: %.6f\n', investmentCER*100);
fprintf('Benchmark CER (BH): %.6f\n', benchmarkCER*100);
fprintf('Benchmark CER (MA): %.6f\n', benchmarkCER2*100);

% Equity curve 
initial_capital = 1;
start_idx = 37;
cumulative_investment = initial_capital * cumprod(1 + monthlyLastData.InvestmentReturn(start_idx:end), 'omitnan');
cumulative_buy_hold = initial_capital * cumprod(1 + monthlyLastData.MonthlyReturn(start_idx:end), 'omitnan');
plot_dates = monthlyLastData.caldt(start_idx:end);

figure;
hold on;
plot(plot_dates, cumulative_investment, '-k', 'LineWidth', 1.5, 'DisplayName', 'Investment Strategy');
plot(plot_dates, cumulative_buy_hold, '--k', 'LineWidth', 1.5, 'DisplayName', 'Buy & Hold');
xlabel('Date');
ylabel('Cumulative Equity Return');
legend('Location', 'northwest');
grid on;
xlim([plot_dates(1), plot_dates(end)]);
hold off;



