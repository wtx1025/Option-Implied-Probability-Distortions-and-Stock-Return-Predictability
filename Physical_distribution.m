clear;
rng(1); 
% Define loglikelihood of EGARCH model 
function [logLikelihood] = egarchLogLikelihood(params, returns)
    mu = params(1);
    nu = params(2);
    beta = params(3);
    zeta = params(4);
    kappa = params(5);
    
    T = length(returns);
    h = zeros(T, 1);
    z = zeros(T, 1);
    
    h(1) = var(returns);
    z(1) = (returns(1) - mu) / sqrt(h(1));
    
    logLikelihood = 0;
    for t = 2:T
        h(t) = exp(nu + beta * log(h(t-1)) + zeta * (abs(z(t-1)) - sqrt(2/pi)) + kappa * z(t-1));
        z(t) = (returns(t) - mu) / sqrt(h(t));
        logLikelihood = logLikelihood - 0.5 * (log(2 * pi) + log(h(t)) + z(t)^2);
    end
    logLikelihood = -logLikelihood;
end

% Simulation 
function S = simulateEgarch(params, T, S0, returns)
    mu = params(1);
    nu = params(2);
    beta = params(3);
    zeta = params(4);
    kappa = params(5);
    
    h = zeros(T, 1);
    z = randn(T, 1);
    S = zeros(T, 1);
    
    h(1) = var(returns);
    S(1) = S0;
    
    for t = 2:T
        h(t) = exp(nu + beta * log(h(t-1)) + zeta * (abs(z(t-1)) - sqrt(2/pi)) + kappa * z(t-1));
        S(t) = S(t-1) * exp(mu + sqrt(h(t)) * z(t));
    end
end

% load S&P 500 index and option data 
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
option_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
option_data = option_data(option_data.date>datetime(2010, 5, 31), :); 
weekly_dates = unique(option_data.date);
all_distributions = cell(length(weekly_dates), 1); 

% Loop through each weekly date 
for w = 1:length(weekly_dates)
    targetDate = weekly_dates(w); 
    idx = find(sp_data.caldt == targetDate, 1); 
    if idx > 1250
        subData = sp_data(idx-1249:idx, :); 
    else
        error('Not enough data for estimation');
    end
    
    subReturns = log(subData.spindx(2:end) ./ subData.spindx(1:end-1));
    initialPrice = sp_data.spindx(idx);
    
    initialParams = [0.0, -1.0, 0.9, 0.1, 0.1]; % [mu, nu, beta, zeta, kappa]
    options = optimset('fmincon');
    options.Display = 'off';
    options.Algorithm = 'interior-point';
    
    lb = [-0.01, -4, 0, -1, -1]; 
    ub = [0.01, 0, 1, 1, 1]; 
    [estimatedParams, ~] = fmincon(@(params) egarchLogLikelihood(params, subReturns), initialParams, [], [], [], [], lb, ub, [], options);
    
    % Simulate 10000 times and calculate cumulative return 
    numSimulations = 10000;
    timeHorizonIdx = find(option_data.date == targetDate, 1); 
    timeHorizon = option_data.time_to_maturity_days(timeHorizonIdx);
    timeHorizon = timeHorizon - idivide(int32(timeHorizon), 7, 'fix') * 2; 
    finalReturns = zeros(numSimulations, 1);
    
    for i = 1:numSimulations
        simulatedPrices = simulateEgarch(estimatedParams, timeHorizon, initialPrice, subReturns);
        finalReturns(i) = (simulatedPrices(end) / initialPrice) - 1;
    end
    
    % kernel density estimation 
    sigma = std(finalReturns); 
    N = length(finalReturns); 
    bandwidth = 0.9 * (N^(-0.2)) * sigma; 
    xi = linspace(-0.5, 0.8, 200); 
    f = ksdensity(finalReturns, xi, 'Bandwidth', bandwidth, 'Function', 'cdf'); 
    discreteDistribution = table(xi(:), f(:), 'VariableNames', {'State', 'Probability'});

    % Store result 
    all_distributions{w} = discreteDistribution; 
    fprintf('Processed date: %s with time horizon: %d days and initial %.6f\n', char(targetDate), timeHorizon, var(subReturns));
end 

save("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EGARCH2.mat", 'all_distributions', 'weekly_dates');
fprintf('Successfully save the estimation results!');


   











