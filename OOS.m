clear;

% read data
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates1.csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
sp_data.YearMonth = dateshift(sp_data.caldt, 'start', 'month');
[~, lastDayIdx] = unique(sp_data.YearMonth, 'last');
monthlyLastData = sp_data(lastDayIdx, :);
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");
rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); % ER_{t}

startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
monthlyLastData = monthlyLastData(monthlyLastData.caldt >= startDate & monthlyLastData.caldt <= endDate, :);
data.Date = datetime(data.Date);
data = data(data.Date >= startDate & data.Date <= endDate, :);

mergedData = [monthlyLastData, data(:, {'Alpha'})]; % merge monthlyLastData & data 
mergedData.ExcessReturn_t1 = [mergedData.ExcessReturn(2:end); NaN];

% split data into IS and OS 
splitDate = datetime(2020, 1, 1);
IS_data = mergedData(mergedData.caldt < splitDate, :);
OOS_data = mergedData(mergedData.caldt >= splitDate, :);

% Estimate coefficient 
X_IS = IS_data.Alpha(1:end-1);
X_IS_mean = mean(X_IS, 'omitnan'); 
X_IS_std = std(X_IS, 'omitnan'); 
X_IS_standardized = (X_IS - X_IS_mean) / X_IS_std; 
Y_IS = IS_data.ExcessReturn_t1(1:end-1);
X_with_intercept_IS = [ones(size(X_IS_standardized)), X_IS_standardized];
b = regress(Y_IS, X_with_intercept_IS);

% OOS prediction
X_OOS = OOS_data.Alpha(1:end-1);
X_OOS_standardized = (X_OOS - X_IS_mean) / X_IS_std; 
Y_actual_OOS = OOS_data.ExcessReturn_t1(1:end-1); 
Y_predicted_OOS = b(1) + b(2) * X_OOS_standardized; 

% IS prediction
Y_predicted_IS = b(1) + b(2) * X_IS_standardized; 

% Benchmark prediction
benchmark_prediction_IS = mean(IS_data.ExcessReturn_t1, 'omitnan');
benchmark_prediction_OOS = mean(IS_data.ExcessReturn_t1, 'omitnan');

% Calculate MSPE
% IS
model_predictionErrors_IS = Y_IS - Y_predicted_IS;
model_MSPE_IS = mean(model_predictionErrors_IS .^ 2, 'omitnan');
benchmark_predictionErrors_IS = Y_IS - benchmark_prediction_IS;
benchmark_MSPE_IS = mean(benchmark_predictionErrors_IS .^ 2, 'omitnan');

% OOS
model_predictionErrors_OOS = Y_actual_OOS - Y_predicted_OOS;
model_MSPE_OOS = mean(model_predictionErrors_OOS .^ 2, 'omitnan');
benchmark_predictionErrors_OOS = Y_actual_OOS - benchmark_prediction_OOS;
benchmark_MSPE_OOS = mean(benchmark_predictionErrors_OOS .^ 2, 'omitnan');

% All Sample
all_actual = [Y_IS; Y_actual_OOS];
all_predicted = [Y_predicted_IS; Y_predicted_OOS];
all_benchmark = benchmark_prediction_IS * ones(size(all_actual));

model_predictionErrors_All = all_actual - all_predicted;
benchmark_predictionErrors_All = all_actual - all_benchmark;

model_MSPE_All = mean(model_predictionErrors_All .^ 2, 'omitnan');
benchmark_MSPE_All = mean(benchmark_predictionErrors_All .^ 2, 'omitnan');

% Calculate R-squared
R2_IS = 1 - (model_MSPE_IS / benchmark_MSPE_IS);
R2_OOS = 1 - (model_MSPE_OOS / benchmark_MSPE_OOS);
R2_All = 1 - (model_MSPE_All / benchmark_MSPE_All);

fprintf('Coefficient: a = %.4f, b = %.4f\n', b(1), b(2));
fprintf('In-Sample R-squared: %.4f\n', R2_IS);
fprintf('Out-of-Sample R-squared: %.4f\n', R2_OOS);
fprintf('All-Sample R-squared: %.4f\n', R2_All);

fprintf('In-Sample MSPE (Model): %.6f\n', model_MSPE_IS);
fprintf('In-Sample MSPE (Benchmark): %.6f\n', benchmark_MSPE_IS);
fprintf('Out-of-Sample MSPE (Model): %.6f\n', model_MSPE_OOS);
fprintf('Out-of-Sample MSPE (Benchmark): %.6f\n', benchmark_MSPE_OOS);
fprintf('All-Sample MSPE (Model): %.6f\n', model_MSPE_All);
fprintf('All-Sample MSPE (Benchmark): %.6f\n', benchmark_MSPE_All);



