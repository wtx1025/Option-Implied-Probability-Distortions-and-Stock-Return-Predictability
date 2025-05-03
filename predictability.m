clear;

% Curvature monthly index 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates2.csv"); 
data.YearMonth = dateshift(data.Date, 'start', 'month');
monthlyData = varfun(@mean, data, 'InputVariables', 'EstimatedState', ...
                     'GroupingVariables', 'YearMonth');

[~, lastDayIdx] = unique(data.YearMonth, 'last');
lastDayDates = data.Date(lastDayIdx);
monthlyData.LastDay = lastDayDates;
monthlyData = monthlyData(:, {'LastDay', 'YearMonth', 'mean_EstimatedState'});
monthlyData.Properties.VariableNames = {'Date', 'YearMonth', 'AverageIndex'};

monthlyData.StandardizedCurvature = (monthlyData.AverageIndex - mean(monthlyData.AverageIndex, 'omitnan')) ./ ...
                                     std(monthlyData.AverageIndex, 'omitnan');

% S&P 500 index 
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
filteredData = sp_data(sp_data.caldt >= startDate & sp_data.caldt <= endDate, :);

filteredData.YearMonth = dateshift(filteredData.caldt, 'start', 'month');
[~, lastDayIdx] = unique(filteredData.YearMonth, 'last');
monthlyLastData = filteredData(lastDayIdx, :);
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

[commonMonths, idx1, idx2] = intersect(monthlyData.YearMonth, monthlyLastData.YearMonth);
alignedData = table(...
    monthlyData.AverageIndex(idx1(1:end-1)), ...
    1 ./ monthlyData.AverageIndex(idx1(1:end-1)), ...
    monthlyLastData.MonthlyReturn(idx2(2:end)), ...
    'VariableNames', {'X', 'X_squared', 'Y'}); % Align X and Y

alignedData = rmmissing(alignedData);

X = alignedData.X_squared; 
Y = alignedData.Y;
X_with_intercept = [ones(size(X)), X]; % 加入截距項

% 執行線性回歸
[b, ~, ~, ~, stats] = regress(Y, X_with_intercept);

% 顯示回歸結果
fprintf('Regression Coefficients:\n');
fprintf('Intercept: %.4f\n', b(1));
fprintf('Slope: %.4f\n', b(2));
fprintf('R-squared: %.4f\n', stats(1));
fprintf('F-statistic: %.4f\n', stats(2));
fprintf('P-value: %.4f\n', stats(3));

figure;
scatter(X, Y, 'filled');
hold on;
plot(X, X_with_intercept * b, 'r', 'LineWidth', 2);
xlabel('Mean Estimated State (X)');
ylabel('Monthly Return (Y)');
title('Regression: Predicted Monthly Returns vs. Estimated State');
grid on;
