clear; 

% read data 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
data = data(data.date>datetime(2010, 5, 31), :); 
distributions = load("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EGARCH2.mat");
weekly_dates = distributions.weekly_dates; 

% connect each date and its physical distribution 
dateToTableMap = containers.Map(); 
for i = 1:length(weekly_dates)
    dateToTableMap(char(weekly_dates(i))) = distributions.all_distributions{i};
end 

% parameter estimation (mu, phi_alpha, variance_alpha, gamma, variance_iv)
initialParams = [1, 0.1, 0.05, 1, 0.003];
lb = [0.8, -0.5, 0.01, 0.001,  0.001];                      
ub = [1.2, 0.5, 0.1, 5, 0.005];                                             

options = optimoptions('fmincon', ...
    'Algorithm', 'interior-point', ...
    'Display', 'iter-detailed', ...
    'MaxIterations', 50,...
    'StepTolerance', 1e-4); 

objFunc = @(params) likelihood(params, data, dateToTableMap);
[optimalParams, optimalFval] = fmincon(objFunc, initialParams,...
    [], [], [], [], lb, ub, [], options);

fprintf('Optimal Parameters: %s\n', mat2str(optimalParams));
fprintf('Function minimum value: f(x) = %.4f\n', optimalFval);