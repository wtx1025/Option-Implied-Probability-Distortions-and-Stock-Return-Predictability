clear;
%% Out-of-sample test using expanding window 
% benchmark performance (MSPE)
data = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
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
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); % Monthly Excess Return

data.one_month_BenchmarkPrediction = NaN(height(data), 1); 
data.three_month_BenchmarkPrediction = NaN(height(data), 1); 
data.six_month_BenchmarkPrediction = NaN(height(data), 1); 
data.twelve_month_BenchmarkPrediction = NaN(height(data), 1); 

for i = 1:height(data)
    targetDate = data.yyyymm(i);
    idx = find(monthlyLastData.caldt < targetDate); 
    if length(idx) >= 36
        pastReturns = monthlyLastData.ExcessReturn(idx);
        data.one_month_BenchmarkPrediction(i) = mean(pastReturns, 'omitnan'); 
        data.three_month_BenchmarkPrediction(i+2) = mean(pastReturns, 'omitnan'); 
        data.six_month_BenchmarkPrediction(i+5) = mean(pastReturns, 'omitnan');
        data.twelve_month_BenchmarkPrediction(i+11) = mean(pastReturns, 'omitnan'); 
    end
end 

data = data(1:height(monthlyLastData), :);

% Initialize prediction errors for different horizons
horizons = [1, 2, 3, 6, 12];
benchmark_mspe = zeros(1, length(horizons));
model_mspe = zeros(1, length(horizons));
oos_rsquared = zeros(1, length(horizons));
estimated_b2 = cell(1, length(horizons));

for h = 1:length(horizons)
    horizon = horizons(h);

    if horizon==1
        benchmarkPrediction = data.one_month_BenchmarkPrediction; 
    elseif horizon==3
        benchmarkPrediction = data.three_month_BenchmarkPrediction; 
    elseif horizon==6
        benchmarkPrediction = data.six_month_BenchmarkPrediction; 
    else
        benchmarkPrediction = data.twelve_month_BenchmarkPrediction;
    end 

    % Calculate multi-period excess returns
    multiPeriodReturns = NaN(height(monthlyLastData), 1);
    for t = horizon:height(monthlyLastData)  
        multiPeriodReturns(t) = sum(monthlyLastData.ExcessReturn(t - horizon + 1:t)) / horizon;
    end

    % Benchmark MSPE
    predictionErrors = multiPeriodReturns - benchmarkPrediction;
    benchmark_mspe(h) = mean(predictionErrors .^ 2, 'omitnan');

    % Model performance (OOS R-squared)
    alignedData = table(data.yyyymm, data.b_m, multiPeriodReturns, ... % change one places when using different predictors 
        'VariableNames', {'Date', 'Predictor', 'ExcessReturn'});

    n = 36; 
    predictedReturn = NaN(height(alignedData), 1);
    b2_coefficients = NaN(height(alignedData)-n, 1);

    for t = n:height(alignedData)-horizon 
        X = alignedData.Predictor(1:t-horizon);
        Y = alignedData.ExcessReturn(1+horizon:t);
        X_mean = mean(X, 'omitnan');
        X_std = std(X, 'omitnan'); 
        X_standardized = (X - X_mean) / X_std; 
        X_with_intercept = [ones(size(X_standardized)), X_standardized]; 
        b = regress(Y, X_with_intercept);
        predictor = (alignedData.Predictor(t) - X_mean) / X_std; 
        predictedReturn(t+horizon) = b(1) + b(2) * predictor; 
        b2_coefficients(t-n+1) = b(2);
    end

    estimated_b2{h} = b2_coefficients;

    actualReturn = alignedData.ExcessReturn; % multiPeriodReturns 
    errors = (predictedReturn(n+1:height(alignedData)-horizon+1) - actualReturn(n+horizon:height(alignedData))) .^ 2;
    model_mspe(h) = mean(errors(1:end), 'omitnan'); 
    oos_rsquared(h) = 1 - (model_mspe(h) / benchmark_mspe(h)); 

    fprintf('Horizon: %d months\n', horizon);
    fprintf('  Benchmark MSPE: %.6f\n', benchmark_mspe(h));
    fprintf('  Model MSPE: %.6f\n', model_mspe(h));
    fprintf('  OOS R-squared: %.4f\n', oos_rsquared(h));
end