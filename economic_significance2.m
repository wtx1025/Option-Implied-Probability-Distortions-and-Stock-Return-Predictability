clear;

%% This codes test the economic significance of PWI by constrcuting investment strategy
combine_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\test.csv");
data = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");
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
if isnumeric(data.yyyymm)
    data.yyyymm = datetime(num2str(data.yyyymm), 'InputFormat', 'yyyyMM');
end
data = data(data.yyyymm >= startDate & data.yyyymm <= endDate, :); 

rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");
rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.DTB3 = monthlyLastData.DTB3 / (100 * 12);
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3; 

% Return prediction 
selectedVars = {'b_m', 'tbl', 'lty', 'ntis', 'infl', 'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de',...
    'tms', 'dfy', 'dfs'};

for i = 1:length(selectedVars)
    varName = selectedVars{i};
    predictedReturn = NaN(height(monthlyLastData), 1);
    n = 36;
    for t = n:height(monthlyLastData)-1
        X = data.(varName)(1:t-1);
        Y = monthlyLastData.MonthlyReturn(2:t);
        X_mean = mean(X, 'omitnan');
        X_std = std(X, 'omitnan');
        X_standardized = (X - X_mean) / X_std;
        X_with_intercept = [ones(size(X_standardized)), X_standardized];
        
        b = regress(Y, X_with_intercept);
        predictor_t = (data.(varName)(t) - X_mean) / X_std;
        predictedReturn(t) = b(1) + b(2) * predictor_t;
    end 
    
    predictedReturn = [combine_data.DMSPE(2:end); NaN]; % use this line for faorecast combination 
    gamma = 3;
    monthlyLastData.PredictedReturn = predictedReturn;
    monthlyLastData.weight = 1/gamma * (monthlyLastData.PredictedReturn - monthlyLastData.DTB3)...
        ./ ((monthlyLastData.RollingStd) * sqrt(20)) .^ 2; 
    
    valid_weights = ~isnan(monthlyLastData.weight);
    monthlyLastData.weight(valid_weights) = max(-0.5, min(1.5, monthlyLastData.weight(valid_weights)));
    
    shifted_weight = [NaN; monthlyLastData.weight(1:end-1)];
    
    monthlyLastData.InvestmentReturn = shifted_weight .* monthlyLastData.MonthlyReturn +...
        (1 - shifted_weight) .* monthlyLastData.DTB3; 
    
    total_investment_excess_return = monthlyLastData.InvestmentReturn - monthlyLastData.DTB3;
    total_benchmark_excess_return = monthlyLastData.MonthlyReturn(n+1:end) - monthlyLastData.DTB3(n+1:end);
    investment_mean_excess = mean(total_investment_excess_return, 'omitnan');
    benchmark_mean_excess = mean(total_benchmark_excess_return, 'omitnan');
    investment_std_excess = std(total_investment_excess_return, 'omitnan');
    benchmark_std_excess = std(total_benchmark_excess_return, 'omitnan');
    total_investment_sharpe = investment_mean_excess / investment_std_excess;
    total_benchmark_sharpe = benchmark_mean_excess / benchmark_std_excess;
    
    %fprintf('Total Investment Sharpe Ratio: %.6f\n', total_investment_sharpe * 12/sqrt(12));
    %fprintf('Total Benchmark Sharpe Ratio: %.6f\n', total_benchmark_sharpe * 12/sqrt(12));
    
    investmentCER = investment_mean_excess * 12 - 0.5 * gamma * (investment_std_excess * sqrt(12)) ^ 2;
    fprintf('Total Investment CER of %s: %.6f\n', varName, investmentCER*100);
end 