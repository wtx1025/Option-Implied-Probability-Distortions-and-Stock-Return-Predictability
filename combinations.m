clear; 
estimated_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\EstimatedStates1.csv");
gw_data = readtable("C:\Users\王亭烜\Downloads\return prediction(1).csv");
sp_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\sp_raw_data.csv");
rf_data = readtable("C:\Users\王亭烜\Desktop\Thesis\Data\data1221\rf_raw_data.xlsx");

% data cleaning
sp_data.YearMonth = dateshift(sp_data.caldt, 'start', 'month'); 
[~, lastDayIdx] = unique(sp_data.YearMonth, 'last'); 
monthlyLastData = sp_data(lastDayIdx, :); 
monthlyLastData.MonthlyReturn = [NaN; diff(log(monthlyLastData.spindx))];

rf_data.observation_date = datetime(rf_data.observation_date);
monthlyLastData = innerjoin(monthlyLastData, rf_data, 'LeftKeys', 'caldt', 'RightKeys', 'observation_date');
monthlyLastData.ExcessReturn = monthlyLastData.MonthlyReturn - monthlyLastData.DTB3 / (100*12); 

startDate = datetime(2010, 6, 1);
endDate = datetime(2023, 8, 31);
estimated_data = estimated_data(estimated_data.Date >= startDate & estimated_data.Date <= endDate, :);
monthlyLastData = monthlyLastData(monthlyLastData.caldt >= startDate & monthlyLastData.caldt <= endDate, :);
if isnumeric(gw_data.yyyymm)
    gw_data.yyyymm = datetime(num2str(gw_data.yyyymm), 'InputFormat', 'yyyyMM'); 
end 
gw_data = gw_data(gw_data.yyyymm >= startDate & gw_data.yyyymm <= endDate, :);

mergedData = [monthlyLastData, estimated_data(:, {'Alpha'}), gw_data];
mergedData = mergedData(:, {'caldt', 'spindx', 'MonthlyReturn', 'ExcessReturn', 'Alpha', 'b_m', 'tbl', 'lty', 'ntis', 'infl',...
    'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de', 'tms', 'dfy', 'dfs'}); 

%% Generate predeiction for all the predictors and benchmark (5 methods)
mergedData.BenchmarkPrediction = NaN(height(mergedData), 1);
for i = 1:height(mergedData)
    targetDate = mergedData.caldt(i);
    idx = find(mergedData.caldt < targetDate);
    if length(idx) >= 36
        pastReturns = mergedData.ExcessReturn(idx);
        mergedData.BenchmarkPrediction(i) = mean(pastReturns, 'omitnan'); 
    end 
end 

benchmarkErrors = mergedData.ExcessReturn - mergedData.BenchmarkPrediction; 
benchmark_mspe = mean(benchmarkErrors .^ 2, 'omitnan');

selectedVars = {'Alpha', 'b_m', 'tbl', 'lty', 'ntis', 'infl',...
    'ltr', 'svar', 'log_dp', 'log_dy', 'log_ep', 'log_de', 'tms', 'dfy', 'dfs'};

n = 36;
for i = 1:length(selectedVars)
    varName = selectedVars{i};
    newVarName = strcat(varName, '_predict'); 
    mergedData.(newVarName) = NaN(height(mergedData), 1);
    for t = n:height(mergedData)-1
        X = mergedData.(varName)(1:t-1); 
        Y = mergedData.MonthlyReturn(2:t);
        X_mean = mean(X, 'omitnan');
        X_std = std(X, 'omitnan'); 
        X_standardized = (X - X_mean) / X_std; 
        X_with_intercept = [ones(size(X_standardized)), X_standardized];
        b = regress(Y, X_with_intercept);
        predictor = (mergedData.(varName)(t) - X_mean) / X_std; 
        mergedData.(newVarName)(t+1) = b(1) + b(2) * predictor; 
    end 
end 

%% for EWC approach, EWC represent the exclusion of PWI while EWC_PWI represents the inclusion of PWI
% Equal-weighted combination 
mergedData.EWC = 1/14 * (mergedData.b_m_predict + mergedData.tbl_predict + mergedData.lty_predict +...
    mergedData.ntis_predict + mergedData.infl_predict + mergedData.ltr_predict + mergedData.svar_predict +...
    mergedData.log_dp_predict + mergedData.log_dy_predict + mergedData.log_ep_predict +...
    mergedData.log_de_predict + mergedData.tms_predict + mergedData.dfy_predict + mergedData.dfs_predict); 
mergedData.EWC_PWI = 1/15 * (mergedData.b_m_predict + mergedData.tbl_predict + mergedData.lty_predict +...
    mergedData.ntis_predict + mergedData.infl_predict + mergedData.ltr_predict + mergedData.svar_predict +...
    mergedData.log_dp_predict + mergedData.log_dy_predict + mergedData.log_ep_predict +...
    mergedData.log_de_predict + mergedData.tms_predict + mergedData.dfy_predict + mergedData.dfs_predict +...
    mergedData.Alpha_predict); 

EWC_error = mergedData.EWC - mergedData.ExcessReturn;
EWC_mspe = mean(EWC_error .^ 2, 'omitnan');
EWC_r2 = 1 - EWC_mspe / benchmark_mspe;
EWC_PWI_error = mergedData.EWC_PWI - mergedData.ExcessReturn;
EWC_PWI_mspe = mean(EWC_PWI_error .^ 2, 'omitnan'); 
EWC_PWI_r2 = 1 - EWC_PWI_mspe / benchmark_mspe; 

%% for TMC, DMSPE, and YANG approach, add 'Alpha_predict' to predictions to account for the inclusion of PWI as predictors 
% Trimmed mean combination 
predictions = {'Alpha_predict', 'b_m_predict', 'tbl_predict', 'lty_predict', 'ntis_predict', 'infl_predict',...
    'ltr_predict', 'svar_predict', 'log_dp_predict', 'log_dy_predict', 'log_ep_predict',...
    'log_de_predict', 'tms_predict', 'dfy_predict', 'dfs_predict'};
for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_trimmed');
    mergedData.(newVarName) = NaN(height(mergedData), 1);
end 

for t = n:height(mergedData)-1
    pre_mspe = NaN(1, length(predictions));
    for i = 1:length(predictions)
        varName = predictions{i};
        mspe = (mergedData.(varName)(t) - mergedData.ExcessReturn(t))^2;
        pre_mspe(i) = mspe;
    end 

    maximum = max(pre_mspe);
    for m = 1:length(predictions)
        varName = predictions{m};
        newVarName = strcat(varName, '_trimmed');
        mspe = (mergedData.(varName)(t) - mergedData.ExcessReturn(t))^2;
        if mspe == maximum
            mergedData.(newVarName)(t+1) = 0;
        else
            mergedData.(newVarName)(t+1) = 1;
        end 
    end 
end 

mergedData.TMC = zeros(height(mergedData), 1);
for i = 1:length(predictions)
    varName1 = predictions{i};
    varName2 = strcat(varName, '_trimmed');
    mergedData.TMC = mergedData.TMC + 1/13 .* mergedData.(varName1) .* mergedData.(varName2); 
end 

TMC_error = mergedData.TMC - mergedData.ExcessReturn;
TMC_mspe = mean(TMC_error .^ 2, 'omitnan');
TMC_r2 = 1 - TMC_mspe / benchmark_mspe; 

% DMSPE
tilde = 0.9; 
mergedData.DMSPE = zeros(height(mergedData), 1);
mergedData.phi_sum = zeros(height(mergedData), 1); 

for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_phi');
    newVarName2 = strcat(varName, '_dmspe');
    mergedData.(newVarName) = NaN(height(mergedData), 1);
    mergedData.(newVarName2) = NaN(height(mergedData), 1); 
end 

for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_phi');
    for m = 37:height(mergedData)
        phi = 0;
        for n = 37:m
            phi = phi + (mergedData.(varName)(n) - mergedData.ExcessReturn(n)).^2 * tilde^(m-n);
        end
        mergedData.(newVarName)(m) = phi;
    end
end

for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_phi');
    mergedData.phi_sum = mergedData.phi_sum + 1 ./ mergedData.(newVarName); 
end 

for i = 37:height(mergedData)-1
    for m = 1:length(predictions)
        varName = predictions{m};
        newVarName = strcat(varName, '_dmspe');
        newVarName2 = strcat(varName, '_phi'); 
        mergedData.(newVarName)(i+1) = (1 / mergedData.(newVarName2)(i)) / mergedData.phi_sum(i);
    end
end 

for i = 1:length(predictions)
    varName1 = predictions{i};
    varName2 = strcat(varName, '_dmspe');
    mergedData.DMSPE = mergedData.DMSPE + mergedData.(varName1) .* mergedData.(varName2); 
end 

% Yang (2004) 
mergedData.YANG = zeros(height(mergedData), 1); 
for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_exp');
    newVarName2 = strcat(varName, '_expweight');
    mergedData.(newVarName) = NaN(height(mergedData), 1);
    mergedData.(newVarName2) = NaN(height(mergedData), 1); 
end 

for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_exp');
    for m = 38:height(mergedData)
        sum = 0;
        for n = 37:m-1
            sum = sum + (mergedData.(varName)(n) - mergedData.ExcessReturn(n)).^2;
        end
        mergedData.(newVarName)(m) = exp(sum);
    end
end

mergedData.exp_sum = zeros(height(mergedData), 1);
for i = 1:length(predictions)
    varName = predictions{i};
    newVarName = strcat(varName, '_exp');
    mergedData.exp_sum = mergedData.exp_sum + mergedData.(newVarName); 
end 

for i = 38:height(mergedData)
    for m = 1:length(predictions)
        varName = predictions{m};
        newVarName = strcat(varName, '_expweight');
        newVarName2 = strcat(varName, '_exp'); 
        mergedData.(newVarName)(i) = mergedData.(newVarName2)(i) / mergedData.exp_sum(i);
    end
end 

for i = 1:length(predictions)
    varName1 = predictions{i};
    varName2 = strcat(varName, '_expweight');
    mergedData.YANG = mergedData.YANG + mergedData.(varName1) .* mergedData.(varName2); 
end 

outputFilePath = "C:\\Users\\王亭烜\\Desktop\\Thesis\\Data\\data1221\\test.csv";
writetable(mergedData, outputFilePath);
fprintf('Successfully saved monthly data to %s\n', outputFilePath);