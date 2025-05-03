function loglikelihood = likelihood(params, data, dateToTableMap)
    % params1: mu
    % params2: phi_alpha
    % params3: variance_alpha
    % params4: gamma
    % params5: variance_iv 

    % pre settings 
    gamma = params(4); 
    phi_alpha = params(2);
    processMean = 0; 
    processVariance = params(3); 
    observationMean = 0;
    x0Guess = 1 / (1 + phi_alpha); 
    %xVec = (x0Guess - 0.8):0.05:(x0Guess + 1); 
    numberParticle = 50; %numel(states); 
    states = phi_alpha * x0Guess + params(1) + sqrt(processVariance) * randn(numberParticle, 1); 
    weights = (1 / numberParticle) * ones(1, numberParticle); 

    dates = unique(data.date);
    numberIterations = numel(dates); 
    stateList = {}; 
    stateList{end+1} = states; 
    weightList = {}; 
    weightList{end+1} = weights;
    loglikelihood = 0; 

    % particle filter algorithm 
    for i = 1:numberIterations 
        rng(1000 * i); 
        newStates = phi_alpha * states + 1 + sqrt(processVariance) * randn(numberParticle, 1);
        newWeights = zeros(1, numberParticle); 

        % information for this iteration 
        currentDate = dates(i); 
        currentDate_data = data(data.date == currentDate, :); 
        currentDate_data.indicator = double(strcmp(currentDate_data.cp_flag, 'C'));
        contractNumber = height(currentDate_data); 
        gridsNum = 200;
        ret_states = dateToTableMap(char(currentDate)).State; 
        probabilities = dateToTableMap(char(currentDate)).Probability; 

        grids = zeros(1, gridsNum);  
        option_payoff = zeros(contractNumber, gridsNum);
        c1s = zeros(1, gridsNum); 
        c2s = zeros(1, gridsNum); 

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
            % Rebound mechanism 
            if newStates(j) < 0.2
                rebound_distance = 0.2 - newStates(j);
                newStates(j) = newStates(j) + 2 * rebound_distance; 
            elseif newStates(j) > 2 
                rebound_distance = newStates(j) - 2; 
                newStates(j) = newStates(j) - 3 * rebound_distance; 
            end

            update_alpha = newStates(j);

            option_price = zeros(contractNumber, 1);
            for k = 1:gridsNum
                option_price = option_price + option_payoff(:, k).*(1+grids(k)).^(-gamma)...
                    .*(exp(-(-log(1-c2s(k)))^update_alpha)...
                    - exp(-(-log(1-c1s(k)))^update_alpha)); 
            end 

            % Calculate the implied volatility (index price, rf, and ttm must be the same for each date)
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
            observationNoise = params(5) * eye(contractNumber);
            observation = market_iv;
            distribution0 = mvnpdf(observation, meanDis, observationNoise) * 10^20;

            newWeights(j) = max(0, real(distribution0 * weights(j))); 
        end 

        if any(isnan(newWeights))
            warning('NaN detected in weights, resetting to minimum weight.');
            minWeight = min(newWeights(~isnan(newWeights))); 
            newWeights(isnan(newWeights)) = minWeight;
        end

        weightStandardized = real(newWeights / sum(newWeights)); 
        Neff = 1 / sum(weightStandardized.^2); 
        if Neff < (numberParticle / 3)
            resampleStateIndex = randsample(1:numberParticle, numberParticle, true, weightStandardized);
            newStates = newStates(resampleStateIndex);
            weightStandardized = (1 / numberParticle) * ones(1, numberParticle); 
        end 

        states = newStates; 
        weights = weightStandardized; 
        stateList{end+1} = states;
        weightList{end+1} = weights; 

        % compute likelihood 
        current_states = stateList{end};
        current_weights = weightList{end}; 
        estimated_alpha = current_states' * current_weights'; 
        model_price = zeros(contractNumber, 1); 
        for k = 1:gridsNum
            model_price = model_price + option_payoff(:, k).*(1+grids(k)).^(-gamma)...
                .*(exp(-(-log(1-c2s(k)))^estimated_alpha)...
                - exp(-(-log(1-c1s(k)))^estimated_alpha));
        end 

        S = currentDate_data.spindx(1);
        r = currentDate_data.DTB3(1); 
        T = currentDate_data.time_to_maturity_days / 250; 
        market_iv = currentDate_data.impl_volatility;
        optionType = currentDate_data.cp_flag;
        model_iv = zeros(contractNumber, 1); 

        for m = 1:contractNumber
            model_iv(m) = impliedVol(S, currentDate_data.strike_price(m) ./ 1000, r, T(m),...
                model_price(m), optionType{m});
        end 

        likelihood = mvnpdf(market_iv, model_iv, params(5) * eye(contractNumber)); 
        if likelihood == 0
            likelihood = -999;
        end 
        loglikelihood = loglikelihood + log(likelihood);

        %fprintf(['Iteration %d done! alpha=%.2f theoretical_iv=%.2f observed_iv=%.2f'...
        %    ' Loglikelihood = %.4f\n'], i, estimated_alpha, model_iv(1),...
        %    market_iv(1), loglikelihood);
    end 

    loglikelihood = -real(loglikelihood);
end