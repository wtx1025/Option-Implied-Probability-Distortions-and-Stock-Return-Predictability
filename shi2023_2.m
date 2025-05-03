clear; 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
data = data(data.date>datetime(2010, 5, 31), :);

data.EndOfMonth = dateshift(data.date, 'end', 'month');
[~, closestIdx] = unique(data.EndOfMonth, 'last');
monthly_dates = data.date(closestIdx);

% initialize
initial_params = [1, 1]; 
lb = [0.2, 0.001];
ub = [2, 15];

results = table('Size', [length(monthly_dates), 4], ...
                'VariableTypes', {'datetime', 'double', 'double', 'double'}, ...
                'VariableNames', {'Date', 'Alpha', 'Gamma', 'Error'});

options = optimoptions('fmincon', ...
    'Display', 'none', ...
    'Algorithm', 'interior-point', ...
    'MaxIterations', 1000, ...
    'MaxFunctionEvaluations', 5000);

% start estimating 
for i = 1:length(monthly_dates)
    target_date = monthly_dates(i);
    objective = @(params) objectiveFunction(target_date, params(1), params(2));
    [optimal_params, optimal_error] = fmincon(objective, initial_params, [], [], [], [], lb, ub, [], options);

    results.Date(i) = target_date;
    results.Predictor(i) = optimal_params(1);
    results.Gamma(i) = optimal_params(2);
    results.Error(i) = optimal_error;

    fprintf('Completed estimation for date: %s estimated alpha: %.2f estimated gamma: %.2f\n', ...
        datestr(target_date), optimal_params(1), optimal_params(2));
end

% plot the results
figure;
subplot(2, 1, 1);
plot(results.Date, results.Predictor, '-o', 'LineWidth', 1.5);
yline(1, 'r--', 'LineWidth', 1.5, 'Label', 'y=1', 'LabelHorizontalAlignment', 'left');
xtickformat('yyyy-MM-dd'); 
xticks(results.Date(1:round(end/10):end));
title('Estimated Alpha Dynamics');
xlabel('Date');
ylabel('Alpha');
grid on;

subplot(2, 1, 2);
plot(results.Date, results.Gamma, '-o', 'LineWidth', 1.5);
xtickformat('yyyy-MM-dd'); 
xticks(results.Date(1:round(end/10):end));
title('Estimated Gamma Dynamics');
xlabel('Date');
ylabel('Gamma');
grid on;

% store the results 
outputFilePath = "C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates3.csv";
writetable(results, outputFilePath);

fprintf('Results saved to %s\n', outputFilePath);
