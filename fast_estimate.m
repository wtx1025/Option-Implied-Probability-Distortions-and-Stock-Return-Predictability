clear;

% read data 
data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\final_data.csv");
data = data(data.date>datetime(2010, 5, 31), :); 
distributions = load("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EGARCH.mat");
weekly_dates = distributions.weekly_dates; 

% connect each date and its physical distribution 
dateToTableMap = containers.Map(); 
for i = 1:length(weekly_dates)
    dateToTableMap(char(weekly_dates(i))) = distributions.all_distributions{i};
end 

% Define noise process
predictMean = 0;
predictNoise = 0.1;
observationMean = 0;

% Define the state space model 
phi_alpha = -0.14; 
A = phi_alpha;
x0 = 1 / (1 - phi_alpha); 
gamma = 1.62; 
gridNums = 200; 

% More setting before starting particle filter 
x0Guess = x0; 
%states = x0Guess + (-0.8:0.025:0.6); % Initial states
numberParticle = 50;
states = phi_alpha * x0Guess + 1.05 + sqrt(predictNoise) * randn(numberParticle, 1);
weights = (1 / numberParticle) * ones(1, numberParticle); 

dates = unique(data.date);
numberIterations = numel(dates); 
stateList = {}; 
stateList{end+1} = states; 
weightList = {}; 
weightList{end+1} = weights;  

% particle filter 
count = 0; 
for i = 1:numberIterations 

    rng(1000*i); 
    newStates = A * states + 1 + normrnd(predictMean, sqrt(predictNoise), [1, numberParticle]); 
    newWeights = zeros(1, numberParticle); 

    % information for this iteration
    currentDate = dates(i); 
    currentDate_data = data(data.date == currentDate, :);
    currentDate_data.indicator = double(strcmp(currentDate_data.cp_flag, 'C'));
    contractNumber = height(currentDate_data); 
    gridsNum = 200; 
    ret_states = dateToTableMap(char(currentDate)).State; % [-0.5, 0.5]
    probabilities = dateToTableMap(char(currentDate)).Probability; % EGARCH simulated distribution

    grids = zeros(1, gridsNum);
    stockPrice = zeros(1, gridsNum); 
    option_payoff = zeros(contractNumber, gridsNum); 
    c1s = zeros(1, gridsNum);
    c2s = zeros(1, gridsNum);  

    % calculate cumulative probability to time t-1 (c1) and time t (c2) at time t
    for k = 1:gridsNum
        currentValue = ret_states(k); 
        grids(k) = currentValue; 
        stock_price = currentDate_data.spindx(1);
        option_payoff(:, k) = max((stock_price.*(1+currentValue) - currentDate_data.strike_price./1000) , 0) .* currentDate_data.indicator + ...
                max((currentDate_data.strike_price./1000 - stock_price.*(1+currentValue)) , 0) .* (1-currentDate_data.indicator); 

        % Calculate cumulative distribution 
        if k == gridsNum
            c2s(k) = probabilities(k);
            c1s(k) = 1; 
        else
            c2s(k) = probabilities(k);
            c1s(k) = probabilities(k+1);
        end 
    end

    for j = 1:numberParticle

        %Rebound mechanism 
        if newStates(j) < 0.2
            rebound_distance = 0.2 - newStates(j);
            newStates(j) = newStates(j) + 2 * rebound_distance; 
        elseif newStates(j) > 1.6 
            rebound_distance = newStates(j) - 2; 
            newStates(j) = newStates(j) - 2 * rebound_distance; 
        end

        update_alpha = newStates(j);

        % if there are n contracts, then we have to calculate n prices
        option_price = zeros(contractNumber, 1);
        for k = 1:gridsNum 
            option_price = option_price + option_payoff(:, k).*(1+grids(k)).^(-gamma)...
                .*(exp(-(-log(1-c2s(k)))^update_alpha)...
                - exp(-(-log(1-c1s(k)))^update_alpha)); 
        end 

        % Calculate the implied volatility  
        S = currentDate_data.spindx(1);
        r = currentDate_data.DTB3(1); 
        T = currentDate_data.time_to_maturity_days / 250; 
        market_iv = currentDate_data.impl_volatility;
        optionType = currentDate_data.cp_flag;
    
        theoretical_iv = zeros(contractNumber, 1); 
        for m = 1:contractNumber 
            theoretical_iv(m) = impliedVol(S, currentDate_data.strike_price(m) ./ 1000, r, T(m),...
                option_price(m), optionType{m});
        end 

        % Update weight for each particle 
        meanDis = theoretical_iv; 
        observationNoise = 0.001 * eye(contractNumber);
        observation = market_iv;
        distribution0 = mvnpdf(observation, meanDis, observationNoise) * 10^10;
 
        newWeights(j) = max(0, real(distribution0 * weights(j))); 
        fprintf('i=%d j=%d alpha=%.2f meanDis=%.4f observed_iv=%.2f prob=%.8f weight=%.10f\n',...
            i, j, update_alpha, meanDis(1), observation(1),...
            distribution0, newWeights(j));
    end 

    % set weight to minimum weight if it is NaN 
    if any(isnan(newWeights))
        warning('NaN detected in weights, resetting to equal weights.');
        minWeight = min(newWeights(~isnan(newWeights))); 
        newWeights(isnan(newWeights)) = minWeight;
    end

    weightStandardized = real(newWeights / sum(newWeights)); 
    tmp1 = weightStandardized.^2; 
    Neff = 1 / sum(tmp1); 
    fprintf('Neff = %.2f\n', Neff);
    if Neff < (numberParticle / 3)
        resampleStateIndex = randsample(1:numberParticle, numberParticle, true, weightStandardized);
        newStates = newStates(resampleStateIndex);
        weightStandardized = (1 / numberParticle) * ones(1, numberParticle); 
    end 

    states = newStates; 
    weights = weightStandardized; 
    stateList{end+1} = states';
    weightList{end+1} = weights; 
    count = count + 1; 
    disp('========================================================================================================') 
end 

% Show the estimate results 
estimatedStates = zeros(1, numberIterations);

for t = 1:numberIterations 
    states_t = stateList{t};
    weights_t = weightList{t};
    
    alpha_t = states_t' * weights_t';
    
    estimatedStates(1, t) = alpha_t;
end

movingAverage = movmean(estimatedStates, 4);
figure;
hold on;

% Convert dates to datetime if they are strings or character vectors
if ischar(dates) || isstring(dates)
    dates = datetime(dates); 
end

plot(dates, estimatedStates, 'ko-', 'Color', [0.6, 0.8, 1], 'LineWidth', 1.5);  
plot(dates, movingAverage, 'k-', 'Color', [0, 0, 0.8], 'LineWidth', 2);
yline(1, 'r--', 'LineWidth', 1.5);
xtickformat('yyyy-MM-dd'); 
xticks(dates(1:round(end/10):end)); 
title('Estimated Alpha Dynamics');
xlabel('Date');
ylabel('Alpha');
grid on;

% Convert weekly estimation to monthly estimation and save the results to a CSV file
resultsTable = table(dates, estimatedStates', 'VariableNames', {'Date', 'EstimatedState'});
resultsTable.YearMonth = dateshift(resultsTable.Date, 'start', 'month');
resultsTable.EstimatedState = 1./ resultsTable.EstimatedState; 
monthlyData = varfun(@mean, resultsTable, 'InputVariables', 'EstimatedState',...
    'GroupingVariables', 'YearMonth'); 

[~, lastDayIdx] = unique(resultsTable.YearMonth, 'last');
lastDayDates = resultsTable.Date(lastDayIdx); 
monthlyData.LastDay = lastDayDates; 

monthlyData = monthlyData(:, {'LastDay', 'YearMonth', 'mean_EstimatedState'});
monthlyData.Properties.VariableNames = {'Date', 'YearMonth', 'Alpha'};
outputFilePath = "C:\\Users\\王亭烜\\Desktop\\Thesis\\Data\\data1221\\EstimatedStates4.csv";
writetable(monthlyData, outputFilePath);
fprintf('Successfully saved monthly data to %s\n', outputFilePath);

% plot the probability weighting index (PWI)
figure;
plot(monthlyData.Date, monthlyData.Alpha, 'kx-', 'LineWidth', 2, 'MarkerSize', 5, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'PWI');
xlabel('Date');
ylabel('PWI');
legend('Location', 'best');
grid on;
datetick('x', 'yyyy-mm', 'keeplimits'); 
hold off;

%{
outputFilePath = "C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates.csv";
writetable(resultsTable, outputFilePath);
fprintf("Successfully save the estimation results!");
%}