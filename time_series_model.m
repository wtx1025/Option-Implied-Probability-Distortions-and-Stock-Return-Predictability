%% This code compares the fitting ability of ARCH, GARCH, and EGARCH 
clear; 
function loglikelihood = archEstimate(params, returns)
    mu = params(1);
    omega = params(2);
    alpha = params(3); 

    T = length(returns); 
    h = zeros(T, 1); 
    h(1) = var(returns); 
    loglikelihood = 0; 

    for t = 2:T
        h(t) = omega + alpha * (returns(t-1) - mu)^2; 
        loglikelihood = loglikelihood - 0.5 * (log(2 * pi) + log(h(t)) + (returns(t) - mu)^2 / h(t)); 
    end 
    loglikelihood = -loglikelihood; 
end 

function loglikelihood = garchEstimate(params, returns)
    mu = params(1);
    omega = params(2); 
    alpha = params(3);
    beta = params(4); 

    T = length(returns);
    h = zeros(T, 1); 
    h(1) = var(returns); 
    loglikelihood = 0; 

    for t = 2:T
        h(t) = omega + alpha * (returns(t-1) - mu)^2 + beta * h(t-1);
        loglikelihood = loglikelihood - 0.5 * (log(2 * pi) + log(h(t)) + (returns(t) - mu)^2 / h(t));
    end
    loglikelihood = -loglikelihood; 
end

function loglikelihood = egarchEstimate(params, returns)
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
    
    loglikelihood = 0;
    for t = 2:T
        h(t) = exp(nu + beta * log(h(t-1)) + zeta * (abs(z(t-1)) - sqrt(2/pi)) + kappa * z(t-1));
        z(t) = (returns(t) - mu) / sqrt(h(t));
        loglikelihood = loglikelihood - 0.5 * (log(2 * pi) + log(h(t)) + z(t)^2);
    end
    loglikelihood = -loglikelihood;
end

data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
data = data(data.caldt > datetime(2010, 5, 31), :);
returns = log(data.spindx(2:end) ./ data.spindx(1:end-1)); 

archInitial = [0, 0.1, 0.1]; 
garchInitial = [0, 0.1, 0.1, 0.8];
egarchInitial = [0.0, -1.0, 0.9, 0.1, 0.1];

archLB = [-inf, 0, 0];
archUB = [inf, inf, inf]; 
garchLB = [-inf, 0, 0, 0];
garchUB = [inf, inf, 1, 1];
egarchLB = [-0.01, -4, 0, -1, -1];
egarchUB = [0.01, 0, 1, 1, 1]; 

options = optimset('fmincon');
options.Display = 'off';
options.Algorithm = 'interior-point';

[archParams, archLogLikelihood, ~, ~, ~, ~, archHessian] = fmincon(@(params) archEstimate(params, returns), ...
    archInitial, [], [], [], [], archLB, archUB, [], options);
[garchParams, garchLogLikelihood, ~, ~, ~, ~, garchHessian] = fmincon(@(params) garchEstimate(params, returns), ...
    garchInitial, [], [], [], [], garchLB, garchUB, [], options);
[egarchParams, egarchLogLikelihood, ~, ~, ~, ~, egarchHessian] = fmincon(@(params) egarchEstimate(params, returns), ...
    egarchInitial, [], [], [], [], egarchLB, egarchUB, [], options);

disp(egarchHessian);
archStdErrors = sqrt(diag(inv(archHessian)));
garchStdErrors = sqrt(diag(inv(garchHessian)));
egarchStdErrors = sqrt(diag(inv(egarchHessian)));
archTStats = archParams' ./ archStdErrors;
garchTStats = garchParams' ./ garchStdErrors;
egarchTStats = egarchParams' ./ egarchStdErrors;
archPValues = 2 * (1 - normcdf(abs(archTStats))); 
garchPValues = 2 * (1 - normcdf(abs(garchTStats))); 
egarchPValues = 2 * (1 - normcdf(abs(egarchTStats))); 

archK = length(archParams); 
garchK = length(garchParams);
egarchK = length(egarchParams); 

archAIC = 2 * archK - 2 * (-archLogLikelihood);
garchAIC = 2 * garchK - 2 * (-garchLogLikelihood);
egarchAIC = 2 * egarchK - 2 * (-egarchLogLikelihood);

fprintf('ARCH(1) Model:\n');
disp(table(archParams', archStdErrors, archTStats, archPValues,...
    'VariableNames', {'Coefficient', 'StdError', 'TStatistic', 'PValue'}));
fprintf('Log-Likelihood: %.6f\n\n', -archLogLikelihood);
fprintf('AIC: %.6f\n\n', archAIC);

fprintf('GARCH(1,1) Model:\n');
disp(table(garchParams', garchStdErrors, garchTStats, garchPValues,...
    'VariableNames', {'Coefficient', 'StdError', 'TStatistic', 'PValue'}));
fprintf('Log-Likelihood: %.6f\n\n', -garchLogLikelihood);
fprintf('AIC: %.6f\n\n', garchAIC);

fprintf('EGARCH(1,1) Model:\n');
disp(table(egarchParams', egarchStdErrors, egarchTStats, egarchPValues,...
    'VariableNames', {'Coefficient', 'StdError', 'TStatistic', 'PValue'}));
fprintf('Log-Likelihood: %.6f\n', -egarchLogLikelihood);
fprintf('AIC: %.6f\n\n', egarchAIC);