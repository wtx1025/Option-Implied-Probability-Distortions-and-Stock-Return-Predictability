clear;

% Step 1: Read Data
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
data = data(data.date > datetime(2010, 5, 31), :); 
distributions = load("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EGARCH.mat");
weekly_dates = distributions.weekly_dates;

% Step 2: Connect each date and its physical distribution
dateToTableMap = containers.Map(); 
for i = 1:length(weekly_dates)
    dateToTableMap(char(weekly_dates(i))) = distributions.all_distributions{i};
end 

% Step 3: Define Parameter Bounds
% Parameter vector: [phi_alpha, variance_alpha, gamma, variance_iv]
lb = [0.2, 0.5, 0.01, 0.001, 0.001];  % Lower bounds
ub = [2, 0.9, 0.1, 5, 0.005];         % Upper bounds

% Step 4: Define Objective Function
% Wrapper to capture the log-likelihood value
global logLikelihoodHistory;
logLikelihoodHistory = []; % Store log-likelihood values during optimization
objFunc = @(params) logLikelihoodWrapper(params, data, dateToTableMap);

% Step 5: Particle Swarm Optimization (PSO) Settings
options = optimoptions('particleswarm', ...
    'SwarmSize', 100, ...             % Number of particles
    'MaxIterations', 500, ...         % Maximum number of iterations
    'Display', 'iter', ...            % Display progress in command window
    'UseParallel', true);             % Enable parallel computation for faster performance

% Step 6: Run PSO
[optimalParams, optimalFval] = particleswarm(objFunc, numel(lb), lb, ub, options);

% Step 7: Display Results
fprintf('Optimal Parameters (PSO): %s\n', mat2str(optimalParams));
fprintf('Function minimum value (Log-Likelihood): %.4f\n', optimalFval);

% Step 8: Plot Log-Likelihood History
figure;
plot(logLikelihoodHistory, '-o');
xlabel('Iteration');
ylabel('Log-Likelihood');
title('Objective Function Values Over Iterations');
grid on;

% Save the log-likelihood history for later analysis
save('logLikelihoodHistory_PSO.mat', 'logLikelihoodHistory');

% Function: Wrapper to log the log-likelihood values
function fval = logLikelihoodWrapper(params, data, dateToTableMap)
    global logLikelihoodHistory;
    fval = likelihood(params, data, dateToTableMap); % Call your actual likelihood function
    logLikelihoodHistory = [logLikelihoodHistory; fval]; % Append current value
end
