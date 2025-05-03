clear;
% read data 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
data = data(data.date>datetime(2010, 5, 31), :);
unique_dates = unique(data.date); 

% Define the date and alpha value for testing
date = unique_dates(1);

% Calibration 
initial_params = [1]; 
lb = [0.5];
ub = [3]; 
options = optimoptions('fmincon', ...
    'Display', 'none', ...
    'Algorithm', 'sqp', ...
    'MaxIterations', 1000, ...
    'MaxFunctionEvaluations', 5000);

objective = @(params) objectiveFunction(date, params(1));
[optimal_params, optimal_error] = fmincon(objective, initial_params, [], [], [], [], lb, ub, [], options);

%{
% Call the objectiveFunction
date = unique_dates(100);
alpha = 1;
pricing_error = objectiveFunction(date, 2);
fprintf('Pricing error for date %s with alpha = %.2f: %.4f\n', date, alpha, pricing_error);
%} 