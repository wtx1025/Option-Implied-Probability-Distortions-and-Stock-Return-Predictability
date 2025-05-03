clear; 
estimated_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates1.csv");
gw_data = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");

% Calculate rolling std 
sp_data.DailyReturn = [NaN; diff(log(sp_data.spindx))];
returns = sp_data.DailyReturn;
rolling_window = 1200;
rolling_std = movstd(returns, rolling_window, 'Endpoints', 'discard');
rolling_std = [NaN(rolling_window-1, 1); rolling_std];
sp_data.RollingStd = rolling_std; 

% data cleaning
sp_data.YearMonth = dateshift(sp_data.caldt, 'start', 'month'); 
[~, lastDayIdx] = unique(sp_data.YearMonth, 'last'); 
monthlyLastData = sp_data(lastDayIdx, :); 
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); 

startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
estimated_data = estimated_data(estimated_data.Date >= startDate & estimated_data.Date <= endDate, :);
monthlyLastData = monthlyLastData(monthlyLastData.caldt >= startDate & monthlyLastData.caldt <= endDate, :);
if isnumeric(gw_data.yyyymm)
    gw_data.yyyymm = datetime(num2str(gw_data.yyyymm), 'InputFormat', 'yyyyMM'); 
end 
gw_data = gw_data(gw_data.yyyymm >= startDate & gw_data.yyyymm <= endDate, :);

mergedData = [monthlyLastData, estimated_data(:, {'Alpha'}), gw_data];
mergedData = mergedData(:, {'caldt', 'spindx', 'ExcessReturn', 'MonthlyReturn', 'DTB3', 'RollingStd', 'Alpha', 'b_m', 'tbl', 'lty', 'ntis', 'infl',...
    'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de', 'tms', 'dfy', 'dfs'});

% Return prediction 
selectedVars = {'b_m', 'tbl', 'lty', 'ntis', 'infl', 'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de',...
    'tms', 'dfy', 'dfs'};

for i = 1:length(selectedVars)
    varName = selectedVars{i};
    predictedReturn = NaN(height(mergedData), 1);
    n = 36;
    for t = n:height(mergedData)-1
        X = mergedData{1:t-1, {'Alpha', varName}};
        Y = mergedData.MonthlyReturn(2:t);
        X_mean = mean(X, 'omitnan');
        X_std = std(X, 'omitnan');
        X_standardized = (X - X_mean) ./ X_std;
        X_with_intercept = [ones(size(X_standardized, 1), 1), X_standardized];
        b = regress(Y, X_with_intercept);
        predictor = (mergedData{t, {'Alpha', varName}} - X_mean) ./ X_std;
        predictor_with_intercept = [1, predictor];
        predictedReturn(t) = predictor_with_intercept * b;
    end 
    
    gamma = 3;
    mergedData.PredictedReturn = predictedReturn;
    mergedData.weight = 1/gamma * (mergedData.PredictedReturn - mergedData.DTB3/1200)...
        ./ (mergedData.RollingStd * sqrt(20)) .^ 2;
    
    valid_weights = ~isnan(mergedData.weight);
    mergedData.weight(valid_weights) = max(-0.5, min(1.5, mergedData.weight(valid_weights)));
    shifted_weight = [NaN; mergedData.weight(1:end-1)];
    mergedData.InvestmentReturn = shifted_weight .* mergedData.MonthlyReturn +...
        (1 - shifted_weight) .* (mergedData.DTB3/1200); 
    
    total_investment_excess_return = mergedData.InvestmentReturn - mergedData.DTB3/1200;
    investment_mean_excess = mean(total_investment_excess_return, 'omitnan');
    investment_std_excess = std(total_investment_excess_return, 'omitnan');
    investmentCER = investment_mean_excess * 12 - 0.5 * gamma * (investment_std_excess * sqrt(12)) ^ 2;
    fprintf('Total Investment CER of %s : %.6f\n', varName, investmentCER*100);
end 
