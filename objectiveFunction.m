function error = objectiveFunction(date, alpha, gamma)
    
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

    % Set the pricing date 
    current_data = data(data.date==date, :);
    current_data.indicator = double(strcmp(current_data.cp_flag, 'C'));
    contractNumber = height(current_data); 

    % Setting parameters 
    gridsNum = 200; 
    states = dateToTableMap(char(date)).State; 
    probabilities = dateToTableMap(char(date)).Probability; 

    % Calculate cumulative probability for each grid 
    grids = zeros(1, gridsNum);
    option_payoff = zeros(contractNumber, gridsNum); 
    c1s = zeros(1, gridsNum);
    c2s = zeros(1, gridsNum); 

    for k = 1:gridsNum
        currentValue = states(k);
        grids(k) = currentValue;
        stock_price = current_data.spindx(1); 
        option_payoff(:,k) = max(stock_price * (1 + currentValue) - current_data.strike_price./1000, 0) .* (current_data.indicator)...
            + max(current_data.strike_price./1000 - stock_price * (1 + currentValue), 0) .* (1-current_data.indicator);

        if k == gridsNum
            c2s(k) = probabilities(k);
            c1s(k) = 1; 
        else
            c2s(k) = probabilities(k);
            c1s(k) = probabilities(k+1);
        end 
    end 

    % Numerical pricing 
    beta = 1;  
    option_price = zeros(contractNumber, 1);
    for k = 1:gridsNum
            option_price = option_price + option_payoff(:,k) .* (1+grids(k))^(-gamma)...
                .* (exp(-(-beta*log(1-c2s(k)))^alpha)- exp(-(-beta*log(1-c1s(k)))^alpha));
    end 

    % Calculate the implied volatility  
    S = current_data.spindx(1);
    r = current_data.DTB3(1); 
    T = current_data.time_to_maturity_days / 250; 
    market_iv = current_data.impl_volatility;
    optionType = current_data.cp_flag;

    theoretical_iv = zeros(contractNumber, 1); 
    parfor i = 1:contractNumber
        theoretical_iv(i) = impliedVol(S, current_data.strike_price(i) ./ 1000, r, T(i),...
            option_price(i), optionType{i});
    end 

    error = sum((theoretical_iv - market_iv).^2, 'omitnan');

    %{
    % Combine market IV and model IV into a table
    market_implied_vol = current_data.impl_volatility; 
    resultTable = table(market_implied_vol, theoretical_iv, ...
        'VariableNames', {'MarketVol', 'TheoreticalVol'});
    fprintf('Pricing Results for date %s:\n', char(date));
    disp(resultTable);
    %} 
end 






    