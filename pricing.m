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

% Set the index of contract we want to price 
index = 4781; 
pricing_date = char(data.date(index)); 

% Setting parameters  
gridsNum = 200; 
states = dateToTableMap(pricing_date).State;
probabilities = dateToTableMap(pricing_date).Probability; 

%{
% Plot states and probabilities as a line plot
figure;
plot(states, probabilities, '-o', 'LineWidth', 1.5);
title('Distribution of States and Probabilities');
xlabel('States');
ylabel('Probabilities');
grid on;
%} 

% Calculate cumulative probability for each grid 
grids = zeros(1, gridsNum); 
option_payoff = zeros(1, gridsNum);
c1s = zeros(1, gridsNum); 
c2s = zeros(1, gridsNum); 

for k = 1:gridsNum
    currentValue = states(k);
    grids(k) = currentValue; 
    stock_price = data{index, 'spindx'}; 
    option_payoff(k) = max(stock_price * (1+currentValue) - data{index, 'strike_price'}/1000, 0);
    %option_payoff(k) = max(data{index, 'strike_price'}/1000 - stock_price * (1+currentValue), 0);

    if k == 1
        c2s(k) = probabilities(k);
        c1s(k) = 0; 
    else
        c2s(k) = probabilities(k); 
        c1s(k) = probabilities(k-1);
    end 

    %{
    c1 = 0;
    c2 = 0;
    if k == 1
        c2 = probabilities(k);
        c1 = 0;
    else
        for s = 1:k-1
            c1 = c1 + probabilities(s);
        end 
        for t = 1:k
            c2 = c2 + probabilities(t); 
        end 
    end 
    c1s(k) = c1;
    c2s(k) = c2; 
    %} 
end 

% Numerical pricing
gamma = 1;
alpha = 0.8;
beta = 1;
option_price = 0;
statePrices = zeros(1, gridsNum); 
decisionWeights = zeros(1, gridsNum); 

for k = 1:gridsNum
    
    decision_weight = exp(-(-beta*log(1-c1s(k)))^alpha)- exp(-(-beta*log(1-c2s(k)))^alpha); 
    decisionWeights(k) = decision_weight; 
    state_price = option_payoff(k)*(1+grids(k))^(-gamma)...
        *decision_weight;
    statePrices(k) = state_price; 
    option_price = option_price + state_price;
end  

fprintf('Pricing Date : %s\n', pricing_date);
fprintf('Index Price : %.2f\n', data{index, 'spindx'});
fprintf('Strike Price : %d\n', data{index, 'strike_price'}/1000);
fprintf('Market Price : %.2f\n', data{index, 'mid_quote'});
fprintf('Model Price : %.2f\n', option_price);


pmf = diff([0; probabilities]);

figure('Position', [100, 100, 1000, 400]);
plot(states(2:end), pmf(2:end), '-ko', 'LineWidth', 1.5, 'DisplayName', 'PMF (Discrete Probabilities)');
hold on;
plot(states(2:end), decisionWeights(2:end), '-x', 'LineWidth', 1.5, 'DisplayName', 'Decision Weights');
title('2020-03-04');
xlabel('States');
ylabel('PMF');
grid on;
legend('Location', 'best');
hold off;



