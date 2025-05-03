clear;

% Estimated Results 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates2.csv");
data2 = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");

% S&P 500 index data 
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
if isnumeric(data2.yyyymm)
    data2.yyyymm = datetime(num2str(data2.yyyymm), 'InputFormat', 'yyyyMM');
end
data2 = data2(data2.yyyymm >= startDate & data2.yyyymm <= endDate, :);
filteredData = sp_data(sp_data.caldt >= startDate & sp_data.caldt <= endDate, :);

filteredData.YearMonth = dateshift(filteredData.caldt, 'start', 'month');
[~, lastDayIdx] = unique(filteredData.YearMonth, 'last');
monthlyLastData = filteredData(lastDayIdx, :);
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

% risk free rate data
rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");
rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); 

% Linear regression
X = data.Alpha(1:end-1);
%X = data2.dfs(1:end-1);
X_mean = mean(X, 'omitnan');
X_std = std(X, 'omitnan'); 
X_standardized = (X - X_mean) / X_std; 
Y = monthlyLastData.ExcessReturn(2:end);
X_with_intercept = [ones(size(X_standardized)), X_standardized];
[b, ~, ~, ~, stats] = regress(Y, X_with_intercept);

fprintf('Regression Results:\n');
fprintf('Intercept: %.4f\n', b(1));
fprintf('Slope: %.4f\n', b(2));
fprintf('R-squared: %.4f\n', stats(1));
fprintf('F-statistic: %.4f\n', stats(2));
fprintf('P-value: %.4f\n', stats(3));


predicted_Y = X_with_intercept * b;

figure;
scatter(X, Y, 'filled'); 
hold on;
plot(X, predicted_Y, 'r', 'LineWidth', 2); 
xlabel('Alpha (X)');
ylabel('Monthly Return (Y)');
title('Simple Regression with Newey-West Standard Errors');
grid on;
